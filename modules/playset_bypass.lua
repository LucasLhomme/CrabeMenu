local Loader = ...
local State = Loader.load("core.state")

-- "Any Character in Any Playset": AaBysT's "Anyone Can Cook II" patch,
-- ported to CrabeLoader with full runtime data transplantation.
-- Native barriers found by signature and flipped in memory:
--   S1    ValidateCurrentCharacter no longer resets the character (jnz -> jmp)
--   S2-S5 no forced playset character (Empire / InsideOut / TheCloneWars / PlaysetX)
--   S6    VirtualReaderPC_GetBrandFromCurrentPlaySet returns nothing (Lua sees nil)
--   S7    IGPGameFlow::IsAvatarValid returns true (no brand/playset validity check)
--   S8    IGPGameFlow::IsMatchingPlaysets returns true (any character in any playset)
--   S9    IGPGameFlow::MissingAvatarCheck skips the DialogType_MissingAvatarQuit popup
--   S10   VirtualReaderPC_GetItemByPage: zone filter off (every character listed)
--   S12   StandAloneLoop::LoadActorLists: loads every playset's actors.lua (native engine loop)
--   S13   StandAloneLoop::LoadDataMaps: loads every playset's DataMap.lua & munitions (native engine loop)
--   S14   CTool::IsAllowedInLevel: bypasses LevelPrefix restriction for 1.0 character innate ranged tools
--   S15   GameplayDataMap::LoadGameplayDataMap: merges duplicate DataMap records across all playsets
-- Note: S11 (previously "GridLockFilterBypass") is intentionally NOT applied and restored:
--   it NOPped FilterMetaData, which broke category filtering and dumped every figure
--   from all franchises into every category in disorder.
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
    { name = "S12 LoadAllActorLists", offset = 43,
      pattern = "C6 45 54 00 8B 0D ?? ?? ?? ?? 8B 81 9C 01 00 00 6A 00 6A 00 50 68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 74 24 20 84 C0 75 ?? 85 F6 74 ?? 32 DB",
      patched = "C6 45 54 00 8B 0D ?? ?? ?? ?? 8B 81 9C 01 00 00 6A 00 6A 00 50 68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 74 24 20 84 C0 75 ?? 85 F6 74 ?? B3 01",
      original = "32 DB", bytes = "B3 01" },
    { name = "S13 LoadAllDataMaps", offset = 43,
      pattern = "C6 45 55 00 8B 0D ?? ?? ?? ?? 8B 81 9C 01 00 00 6A 00 6A 00 50 68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 74 24 20 84 C0 75 ?? 85 F6 74 ?? 32 DB",
      patched = "C6 45 55 00 8B 0D ?? ?? ?? ?? 8B 81 9C 01 00 00 6A 00 6A 00 50 68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 74 24 20 84 C0 75 ?? 85 F6 74 ?? B3 01",
      original = "32 DB", bytes = "B3 01" },
    { name = "S14 ToolLevelPrefixBypass", offset = 27,
      pattern = "53 8B D9 83 7B 74 FF 0F 85 A6 00 00 00 56 33 F6 57 8B 7C 24 10 89 73 74 39 77 08 75 09",
      patched = "53 8B D9 83 7B 74 FF 0F 85 A6 00 00 00 56 33 F6 57 8B 7C 24 10 89 73 74 39 77 08 90 90",
      original = "75 09", bytes = "90 90" },
    { name = "S15 DataMapMergeDuplicates", offset = 9,
      pattern = "80 7C 24 13 00 75 08 84 C0 0F 84 14 04 00 00",
      patched = "80 7C 24 13 00 75 08 84 C0 90 90 90 90 90 90",
      original = "0F 84 14 04 00 00", bytes = "90 90 90 90 90 90" },
}

-- S11 in AaBysT's original patch was misidentified as a lock bypass, but it actually
-- NOPped VirtualReaderPC::FilterMetaData. That broke category filtering and dumped
-- all 105 characters from Star Wars, Marvel and Disney into every tab in disorder.
-- We actively restore it to keep categories cleanly filtered and sorted.
local S11_RESTORE = {
    pattern = "56 8B CF E8 ?? ?? ?? ?? 84 C0 90 90 8D 54 24 10 52",
    offset = 10,
    original = "74 12",
}

local function restoreS11()
    if not (Crabe.Memory and Crabe.Memory.patternScan and Crabe.Memory.patchBytes) then return end
    local address = Crabe.Memory.patternScan(S11_RESTORE.pattern)
    if address then
        Crabe.Memory.patchBytes(address + S11_RESTORE.offset, S11_RESTORE.original)
        log("Restored S11 FilterMetaData: categories and character sorting preserved")
    end
end

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
    restoreS11()
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
    -- 1. Neutralize Disney's Onboard Tutorial (which intentionally disables Back/Escape in Win32 menus)
    if rawget(Globals, "UI_IsOnboardTutorialActive") ~= nil then
        rawset(Globals, "UI_IsOnboardTutorialActive", function() return false end)
    end
    if rawget(Globals, "UI_ShouldOnboardTutorialRestrictInput") ~= nil then
        rawset(Globals, "UI_ShouldOnboardTutorialRestrictInput", function() return false end)
    end

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

    local vrpc = rawget(Globals, "VirtualReaderPC")
    if type(vrpc) == "table" and type(vrpc.IsOnboardTutorialActive) == "function" then
        vrpc.IsOnboardTutorialActive = function() return false end
    end

    local loadout = rawget(Globals, "VirtualReaderPC_Loadout")
    if type(loadout) == "table" then
        if loadout.IsOnboardTutorialActive ~= nil then
            loadout.IsOnboardTutorialActive = function() return false end
        end
        if type(loadout.ScreenDefinition) == "table" then
            loadout.ScreenDefinition.doLuaInput = true
        end
        if type(loadout.HandleCloseButton) == "function" and not loadout._crabeNavPatched then
            loadout._crabeNavPatched = true
            local origClose = loadout.HandleCloseButton
            loadout.HandleCloseButton = function(self)
                if not self.hitContinue then
                    if self.loadUGCHandle ~= nil then
                        local h = UI.GetHandleFromName(self.loadUGCHandle, self.InstanceData.playerNum)
                        if h ~= UI.INVALID_UI_HANDLE then
                            self:CallScreenFunctionByScreenName(self.loadUGCHandle, self.InstanceData.playerNum, "SetScreenActive", true)
                            self:CallScreenFunctionByScreenName(self.loadUGCHandle, self.InstanceData.playerNum, "SetFocus", true)
                        end
                    else
                        local psHandle = UI.GetHandleFromName("PlaysetSelectMenu", 0)
                        if psHandle ~= UI.INVALID_UI_HANDLE then
                            self:CallScreenFunctionByScreenName("PlaysetSelectMenu", self.InstanceData.playerNum, "SetScreenActive", true)
                            self:CallScreenFunctionByScreenName("PlaysetSelectMenu", self.InstanceData.playerNum, "SetFocus", true)
                        else
                            local plHandle = UI.GetHandleFromName("PlaysetListWin32", 0)
                            if plHandle ~= UI.INVALID_UI_HANDLE then
                                self:CallScreenFunctionByScreenName("PlaysetListWin32", self.InstanceData.playerNum, "SetScreenActive", true)
                                self:CallScreenFunctionByScreenName("PlaysetListWin32", self.InstanceData.playerNum, "SetFocus", true)
                            end
                        end
                    end
                end
                origClose(self)
            end
        end
    end

    local tabs = rawget(Globals, "VirtualReaderPC_Tabs")
    if type(tabs) == "table" and tabs.IsOnboardTutorialActive ~= nil then
        tabs.IsOnboardTutorialActive = function() return false end
    end

    local plw = rawget(Globals, "PlaysetListWin32")
    if type(plw) == "table" and type(plw.GoBack) == "function" and not plw._crabeNavPatched then
        plw._crabeNavPatched = true
        plw.GoBack = function(self)
            if self.cloudLoadStarted then return end
            self:RequestExit()
        end
    end

    local mb = rawget(Globals, "MenuBase")
    if type(mb) == "table" and type(mb.GoBack) == "function" and not mb._crabeNavPatched then
        mb._crabeNavPatched = true
        mb.GoBack = function(self)
            self:RequestExit()
        end
    end

    local charGrid = rawget(Globals, "VirtualReaderPC_GridCharacter")
    if type(charGrid) == "table" and charGrid.IsOnboardTutorialActive ~= nil then
        charGrid.IsOnboardTutorialActive = function() return false end
    end

    tagAllCharactersForDory()
end

local function removeLuaLayer()
    if brandOriginal and rawget(Globals, "VirtualReaderPC_GetBrandFromCurrentPlaySet") == noBrand then
        rawset(Globals, "VirtualReaderPC_GetBrandFromCurrentPlaySet", brandOriginal)
    end
    brandOriginal = nil
end

-- Data layer -----------------------------------------------------------------

local PLAYSETS = {
    { id = "theclonewars", package = "TheCloneWars" },
    { id = "empire",       package = "Empire" },
    { id = "playsetx",     package = "PlaysetX" },
    { id = "insideout",    package = "InsideOut" },
}

local dataPatchesRegistered = false

local function registerDataPatches()
    if dataPatchesRegistered then return end
    if not (Crabe.Hooks and type(Crabe.Hooks.patchChunk) == "function") then
        log("Crabe.Hooks.patchChunk not available, skipping data layer")
        return
    end

    local datamapParts = {}
    local actorlistParts = {}

    for _, p in ipairs(PLAYSETS) do
        local okDm, dm = pcall(Loader.load, "modules.playset_patches." .. p.id .. "_datamap")
        local okAl, al = pcall(Loader.load, "modules.playset_patches." .. p.id .. "_actorlist")
        local okBm, bm = pcall(Loader.load, "modules.playset_patches." .. p.id .. "_bitmasks")

        if okDm and type(dm) == "string" then datamapParts[#datamapParts + 1] = dm end
        if okAl and type(al) == "string" then actorlistParts[#actorlistParts + 1] = al end
        if okBm and type(bm) == "string" then
            Crabe.Hooks.patchChunk("Package = '" .. p.package .. "'", bm)
        end
    end

    local nativeAllLoaded = sites["S12 LoadAllActorLists"] and sites["S13 LoadAllDataMaps"]
    if not nativeAllLoaded then
        if #datamapParts > 0 then
            Crabe.Hooks.patchChunk("DataMap", table.concat(datamapParts, "\n"))
        end
        if #actorlistParts > 0 then
            Crabe.Hooks.patchChunk("ActorList", table.concat(actorlistParts, "\n"))
        end
    else
        -- GameplayDataMap::LoadPlayset only runs _loadforallplaysets_ and the active playset,
        -- never DataMap.Playset["toybox"] where munitions_toybox.lua and surfaceimpacts.lua live.
        local toyboxMunitionsPatch = [[
if DataMap and DataMap.Playset then
    local extraFiles = {
        "GameDB|gamedb/core/munitions_toybox.lua|1|munitions",
        "GameDB|gamedb/toybox/surfaceimpacts.lua|1|surfaceImpacts",
    }
    local function addExtra(tbl)
        if not (tbl and tbl.Files) then return end
        local seen = {}
        for _, f in ipairs(tbl.Files) do seen[f] = true end
        for _, f in ipairs(extraFiles) do
            if not seen[f] then tbl.Files[#tbl.Files + 1] = f end
        end
    end
    addExtra(DataMap.Playset._loadforallplaysets_)
    for _, ps in pairs(DataMap.Playset) do addExtra(ps) end
end
]]
        Crabe.Hooks.patchChunk("DataMap", toyboxMunitionsPatch)
        log("Native engine loop active (S12-S15): registered lightweight ToyBox munitions patch")
    end

    dataPatchesRegistered = true
    log(string.format("Bitmasks and data patches registered for %d Play Sets", #PLAYSETS))
end

-- Public API -----------------------------------------------------------------

--- Reports whether the barriers are currently lifted.
function PlaysetBypass.isEnabled()
    return enabled
end

--- Returns how many of the native barriers the last switch flipped, and the total.
function PlaysetBypass.patchCount()
    return patched, total
end

--- Lifts (true) or restores (false) the native barriers, the Lua layer and the data layer.
--- The choice is kept in State.playsetBypass for core.settings to save.
function PlaysetBypass.setEnabled(on)
    on = on == true
    patched = writeAll(on)
    if on then
        registerDataPatches()
        applyLuaLayer()
    else
        removeLuaLayer()
    end
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

local s11VerifiedOnTick = false

--- Re-applies the Lua layer; call once per tick. The native patches stay put.
function PlaysetBypass.onTick()
    if not s11VerifiedOnTick then
        s11VerifiedOnTick = true
        restoreS11()
    end
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
