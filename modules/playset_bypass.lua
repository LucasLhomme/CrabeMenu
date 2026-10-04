local Loader = ...
local State = Loader.load("core.state")

-- "Any Character in Any Playset": AaBysT's "Anyone Can Cook II" exe patch,
-- ported to CrabeLoader (first in Disney Infinity Complete, now owned here).
-- Eleven native barriers, each found by signature and flipped in memory:
--   S1    ValidateCurrentCharacter no longer resets the character (jnz -> jmp)
--   S2-S5 no forced playset character (Empire / InsideOut / TheCloneWars / PlaysetX)
--   S6    VirtualReaderPC_GetBrandFromCurrentPlaySet returns nothing (Lua sees nil)
--   S7    IGPGameFlow::IsAvatarValid returns true (no brand/playset validity check)
--   S8    IGPGameFlow::IsMatchingPlaysets returns true (any character in any playset)
--   S9    IGPGameFlow::MissingAvatarCheck skips the DialogType_MissingAvatarQuit popup
--   S10   VirtualReaderPC_GetItemByPage: zone filter off (every character listed)
--   S11   VirtualReaderPC_GetItemByPage: lock filter off (every character selectable)
-- plus a Lua layer, re-applied every tick because the game reloads these
-- globals with its screens: the Lua brand lookup returns nil, the character
-- grid is hardened against the tables the disabled filters no longer fill,
-- and every catalog row is tagged for the Finding Dory filter.

local PlaysetBypass = {}

local SIGNATURES = {
    { name = "S1 ValidateCurrentCharacter", offset = 16,
      pattern = "8B 87 B0 00 00 00 50 8B CF E8 ?? ?? ?? ?? 84 C0 75 0A C7 87 B0 00 00 00 FF FF FF FF 5E 5F 5B C3",
      patched = "8B 87 B0 00 00 00 50 8B CF E8 ?? ?? ?? ?? 84 C0 EB 0A C7 87 B0 00 00 00 FF FF FF FF 5E 5F 5B C3",
      original = "75", bytes = "EB" },
    { name = "S2 Playset Empire", offset = 21,
      pattern = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0B 8B 87 20 01 00 00 E9 ?? ?? ?? ??",
      patched = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0B 83 C8 FF 90 90 90 E9 ?? ?? ?? ??",
      original = "8B 87 20 01 00 00", bytes = "83 C8 FF 90 90 90" },
    { name = "S3 Playset InsideOut", offset = 21,
      pattern = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0E 8B 8F 24 01 00 00 89 8F B4 00 00 00",
      patched = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0E 83 C9 FF 90 90 90 89 8F B4 00 00 00",
      original = "8B 8F 24 01 00 00", bytes = "83 C9 FF 90 90 90" },
    { name = "S4 Playset TheCloneWars", offset = 21,
      pattern = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0E 8B 97 28 01 00 00 89 97 B4 00 00 00",
      patched = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0E 83 CA FF 90 90 90 89 97 B4 00 00 00",
      original = "8B 97 28 01 00 00", bytes = "83 CA FF 90 90 90" },
    { name = "S5 Playset PlaysetX", offset = 21,
      pattern = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0C 8B 87 2C 01 00 00 89 87 B4 00 00 00",
      patched = "68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B CE E8 ?? ?? ?? ?? 84 C0 74 0C 83 C8 FF 90 90 90 89 87 B4 00 00 00",
      original = "8B 87 2C 01 00 00", bytes = "83 C8 FF 90 90 90" },
    { name = "S6 GetBrandFromCurrentPlaySet", offset = 0,
      pattern = "64 A1 00 00 00 00 6A FF 68 ?? ?? ?? ?? 50 64 89 25 00 00 00 00 83 EC 0C 56 8D 71 20 57 85 F6 0F 84 ?? ?? ?? ?? 8B 81 E4 00 00 00",
      patched = "33 C0 C2 04 00 00 6A FF 68 ?? ?? ?? ?? 50 64 89 25 00 00 00 00 83 EC 0C 56 8D 71 20 57 85 F6 0F 84 ?? ?? ?? ?? 8B 81 E4 00 00 00",
      original = "64 A1 00 00", bytes = "33 C0 C2 04" },
    { name = "S7 IsAvatarValid", offset = 0,
      pattern = "64 A1 00 00 00 00 6A FF 68 ?? ?? ?? ?? 50 64 89 25 00 00 00 00 53 55 56 57 8B 7C 24 24 8B F1 85",
      patched = "B0 01 C2 14 00 00 6A FF 68 ?? ?? ?? ?? 50 64 89 25 00 00 00 00 53 55 56 57 8B 7C 24 24 8B F1 85",
      original = "64 A1 00 00 00", bytes = "B0 01 C2 14 00" },
    { name = "S8 IsMatchingPlaysets", offset = 0,
      pattern = "6A FF 64 A1 00 00 00 00 68 ?? ?? ?? ?? 50 8B 44 24 18 64 89 25 00 00 00 00 83 EC 28 53 55 56 33",
      patched = "B0 01 C2 0C 00 00 00 00 68 ?? ?? ?? ?? 50 8B 44 24 18 64 89 25 00 00 00 00 83 EC 28 53 55 56 33",
      original = "6A FF 64 A1 00", bytes = "B0 01 C2 0C 00" },
    { name = "S9 MissingAvatarQuitBypass", offset = 8,
      pattern = "8B 4E 08 83 7C B9 0C 00 74 3A 8B 56 0C 8B 44 BA 0C 85 C0 75 18",
      patched = "8B 4E 08 83 7C B9 0C 00 EB 23 8B 56 0C 8B 44 BA 0C 85 C0 75 18",
      original = "74 3A", bytes = "EB 23" },
    { name = "S10 GridZoneFilterBypass", offset = 10,
      pattern = "56 8B CF E8 ?? ?? ?? ?? 84 C0 74 28 8D 44 24 64 50 8D 4C 24 58",
      patched = "56 8B CF E8 ?? ?? ?? ?? 84 C0 90 90 8D 44 24 64 50 8D 4C 24 58",
      original = "74 28", bytes = "90 90" },
    { name = "S11 GridLockFilterBypass", offset = 10,
      pattern = "56 8B CF E8 ?? ?? ?? ?? 84 C0 74 12 8D 54 24 10 52",
      patched = "56 8B CF E8 ?? ?? ?? ?? 84 C0 90 90 8D 54 24 10 52",
      original = "74 12", bytes = "90 90" },
}

local GRID_METHODS = {
    "PressedBaseFilterButton",
    "GetCurrentFilterString",
    "SetFilterButtonData",
    "PopulateFilterRow",
    "SelectFilterItem",
}

local EXPORT_NAME = "crabemenu.playsetBypass"

-- The game's own globals. Inside the mod sandbox `_G` is a read-only proxy:
-- rawget on it finds nothing and rawset only writes the proxy, which is how
-- the Disney Infinity Complete version of this layer never applied. The
-- thread's environment is the real table.
local Globals = getfenv(0)

local enabled = false
local sites = {}
local patched, total = 0, #SIGNATURES
local brandOriginal = nil
local hardenedGrid = nil

local function log(message)
    Crabe.write("[CrabeMenu.PlaysetBypass] " .. message)
end

-- Native layer ---------------------------------------------------------------

-- Address of a patch site, found clean or already patched, cached once known.
local function locate(sig)
    if sites[sig.name] then return sites[sig.name] end
    local address = Crabe.Memory.patternScan(sig.pattern) or Crabe.Memory.patternScan(sig.patched)
    if address then sites[sig.name] = address + sig.offset end
    return sites[sig.name]
end

-- Writes every site to its patched or original bytes; returns how many took.
local function writeAll(wantPatched)
    local done = 0
    for _, sig in ipairs(SIGNATURES) do
        local address = locate(sig)
        if not address then
            log(sig.name .. ": signature not found (other game build?), skipped")
        elseif Crabe.Memory.patchBytes(address, wantPatched and sig.bytes or sig.original) then
            done = done + 1
        else
            log(string.format("%s: patchBytes failed at 0x%08X", sig.name, address))
        end
    end
    log(string.format("%s %d/%d native sites", wantPatched and "patched" or "restored", done, total))
    return done
end

-- Lua layer ------------------------------------------------------------------

local function noBrand() return nil end

-- The character grid reads these two tables unguarded; with the filters off
-- they can be missing, which crashed the grid.
local function ensureGridInvariants(self)
    if type(self.filterButtonTextArray) ~= "table" then self.filterButtonTextArray = {} end
    if type(self.staticFilterData) ~= "table" then self.staticFilterData = {} end
end

local function hardenGrid(class)
    local originalEnter = class.onEnter
    class.onEnter = function(self, ...)
        self.filterButtonTextArray = {}
        self.staticFilterData = self.staticFilterData or {}
        return originalEnter(self, ...)
    end
    for _, name in ipairs(GRID_METHODS) do
        local original = class[name]
        if type(original) == "function" then
            class[name] = function(self, ...)
                ensureGridInvariants(self)
                return original(self, ...)
            end
        end
    end
end

-- Tags every catalog row as Dory-compatible once, so the Finding Dory filter
-- lists every character.
local function tagAllCharactersForDory()
    local data = rawget(Globals, "VirtualReaderPC_Data")
    if type(data) ~= "table" or type(data.AvatarData) ~= "table" or data._doryTagged then return end
    data._doryTagged = true
    for _, row in ipairs(data.AvatarData) do
        if type(row) == "table" and type(row.MetaData) == "string" and not row.MetaData:find("Dory", 1, true) then
            row.MetaData = row.MetaData .. ",Dory,DOR"
        end
    end
end

local function applyLuaLayer()
    local current = rawget(Globals, "VirtualReaderPC_GetBrandFromCurrentPlaySet")
    if type(current) == "function" and current ~= noBrand then
        brandOriginal = current
        rawset(Globals, "VirtualReaderPC_GetBrandFromCurrentPlaySet", noBrand)
    end
    local grid = rawget(Globals, "VirtualReaderPC_GridBase")
    if type(grid) == "table" and grid ~= hardenedGrid and type(grid.onEnter) == "function" then
        hardenGrid(grid)
        hardenedGrid = grid
    end
    tagAllCharactersForDory()
end

local function removeLuaLayer()
    if brandOriginal and rawget(Globals, "VirtualReaderPC_GetBrandFromCurrentPlaySet") == noBrand then
        rawset(Globals, "VirtualReaderPC_GetBrandFromCurrentPlaySet", brandOriginal)
    end
    brandOriginal = nil
end

-- Public API -----------------------------------------------------------------

--- Reports whether the barriers are currently lifted.
function PlaysetBypass.isEnabled()
    return enabled
end

--- Returns how many of the eleven native barriers the last switch flipped, and the total.
function PlaysetBypass.patchCount()
    return patched, total
end

--- Lifts (true) or restores (false) the eleven barriers and the Lua layer.
--- The choice is kept in State.playsetBypass for core.settings to save.
function PlaysetBypass.setEnabled(on)
    on = on == true
    patched = writeAll(on)
    if on then applyLuaLayer() else removeLuaLayer() end
    enabled = on
    State.playsetBypass = on

    if not on then
        State.setStatus("Any character in any playset: OFF (original game)", "info")
    elseif patched == total then
        State.setStatus(string.format("Any character in any playset: ON (%d/%d barriers)", patched, total), "success")
    else
        State.setStatus(string.format("Any character in any playset: ON, only %d/%d barriers found", patched, total),
            "warning")
    end
    return true
end

--- Re-applies the Lua layer; call once per tick. The native patches stay put.
function PlaysetBypass.onTick()
    if enabled then applyLuaLayer() end
end

--- Applies the saved choice; on by default, as the original patch was.
function PlaysetBypass.init()
    if State.playsetBypass ~= false then
        PlaysetBypass.setEnabled(true)
    end
end

-- Disney Infinity Complete shipped this patch first; it uses this copy when it
-- finds it, so the two never fight over the same bytes and globals.
Crabe.Sandbox.export(EXPORT_NAME, {
    isEnabled = PlaysetBypass.isEnabled,
    setEnabled = function(on)
        PlaysetBypass.setEnabled(on)
        return State.currentStatus()
    end,
})

return PlaysetBypass
