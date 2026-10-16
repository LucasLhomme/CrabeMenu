local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local Cheats = {}

local Memory = Crabe.Memory

local BLOCK_NAME = "crabemenu.godmode"
local MAGIC = 0x474F4431
local RING_SIZE = 64
local OFFSET = {
    magic = 0x00, enabled = 0x04, player = 0x08, lastDamaged = 0x0C,
    ringIndex = 0x10, flags = 0x14, oneShot = 0x18, ring = 0x20,
}
local BLOCK_SIZE = OFFSET.ring + RING_SIZE * 4
local FLAG_HUD_CAVE = 1
local FLAG_ONE_SHOT_CAVE = 2

local HEALTH_CURRENT = 0x08
local HEALTH_MAX = 0x0C
local MAX_PLAUSIBLE_HEALTH = 1e7

local STOLEN_LENGTH = 5
local DAMAGE_PATTERN = "F3 0F 58 45 08 F3 0F 10 4E 0C 0F 2F C1 57 F3 0F 11 46 08"
local DAMAGE_SITE = 5
local HUD_PATTERN = "85 C0 0F 84 ?? ?? ?? ?? F3 0F 10 40 08 F3 0F 5E 40 0C 0F 2F C8"
local HUD_SITE = 8

local EDITOR_PATTERN = "0F B6 42 20 85 C0 74"
local EDITOR_PATCH_OFFSET = 6
local EDITOR_PATCH = "90 90"

local TICK_INTERVAL = 15

local godBlock = nil
local ticks = 0

local function littleEndian(value)
    local bytes = {}
    for i = 1, 4 do
        bytes[i] = string.format("%02X", value % 256)
        value = math.floor(value / 256)
    end
    return table.concat(bytes, " ")
end

local function openBlock()
    local block = Memory.sharedBlock(BLOCK_NAME, BLOCK_SIZE)
    if block and Memory.readU32(block + OFFSET.magic) == MAGIC then
        godBlock = block
    end
    return block
end

local function hasFlag(flag)
    if not godBlock then return false end
    local flags = Memory.readU32(godBlock + OFFSET.flags) or 0
    return math.floor(flags / flag) % 2 == 1
end

local function hasAutoDetection()
    return hasFlag(FLAG_HUD_CAVE)
end

local function hexLength(bytes)
    local count = 0
    for _ in bytes:gmatch("%x%x") do count = count + 1 end
    return count
end

local function skip(opcode, over)
    return string.format("%s %02X", opcode, hexLength(over))
end

local function guarded(test, jump, body)
    return test .. " " .. skip(jump, body) .. " " .. body
end

local function damageCaveBody(block)
    local function field(name) return littleEndian(block + OFFSET[name]) end

    local record = "89 35 " .. field("lastDamaged")
    local hold = "F3 0F 10 46 0C"
    local god = guarded("3B 35 " .. field("player"), "75", hold)
    local kill = "0F 57 C0"
    local notHero = guarded("3B 35 " .. field("player"), "74", kill)
    local damaging = guarded("F6 45 0B 80", "74", notHero)
    local heroKnown = guarded("83 3D " .. field("player") .. " 00", "74", damaging)

    return table.concat({
        guarded("F6 45 0B 80", "74", record),
        guarded("80 3D " .. field("enabled") .. " 00", "74", god),
        guarded("80 3D " .. field("oneShot") .. " 00", "74", heroKnown),
    }, " ")
end

local function hudCaveBody(block)
    return table.concat({
        "51",
        "8B 0D " .. littleEndian(block + OFFSET.ringIndex),
        "83 E1 3F",
        "89 04 8D " .. littleEndian(block + OFFSET.ring),
        "41",
        "89 0D " .. littleEndian(block + OFFSET.ringIndex),
        "59",
    }, " ")
end

local function installHudCave(block)
    local site = Memory.patternScan(HUD_PATTERN)
    return site ~= nil and Memory.installCodeCave(site + HUD_SITE, hudCaveBody(block), STOLEN_LENGTH)
end

local function installGodCaves()
    if godBlock then return true end

    local block = openBlock()
    if godBlock then return true end
    if not block then return Native.fail("God Mode: shared memory block unavailable") end

    local damageSite = Memory.patternScan(DAMAGE_PATTERN)
    if not damageSite then return Native.fail("God Mode: damage signature not found (game version mismatch?)") end
    if not Memory.installCodeCave(damageSite + DAMAGE_SITE, damageCaveBody(block), STOLEN_LENGTH) then
        return Native.fail("God Mode: damage code cave could not be installed")
    end

    local hudInstalled = installHudCave(block)
    Memory.writeU32(block + OFFSET.flags, (hudInstalled and FLAG_HUD_CAVE or 0) + FLAG_ONE_SHOT_CAVE)
    Memory.writeU32(block + OFFSET.magic, MAGIC)
    godBlock = block
    return true
end

local function isHealthComponent(address)
    if not address or address == 0 then return false end
    local maxHealth = Memory.readFloat(address + HEALTH_MAX)
    return maxHealth ~= nil and maxHealth > 0 and maxHealth < MAX_PLAUSIBLE_HEALTH
end

local function pickPlayerComponent()
    local counts, best, bestCount = {}, nil, 0
    for i = 0, RING_SIZE - 1 do
        local pointer = Memory.readU32(godBlock + OFFSET.ring + i * 4)
        if pointer and pointer ~= 0 then
            local count = (counts[pointer] or 0) + 1
            counts[pointer] = count
            if count > bestCount then best, bestCount = pointer, count end
        end
    end
    if best and isHealthComponent(best) then return best end
    return nil
end

local function refillPlayer()
    if not godBlock then return false end
    local component = Memory.readU32(godBlock + OFFSET.player)
    if not isHealthComponent(component) then return false end

    local maxHealth = Memory.readFloat(component + HEALTH_MAX)
    Memory.writeFloat(component + HEALTH_CURRENT, maxHealth)
    State.playerHealth.current = maxHealth
    State.playerHealth.max = maxHealth
    return true
end

--- Reports whether the invulnerability flag is currently set in game memory.
function Cheats.isGodMode()
    return godBlock ~= nil and Memory.readU32(godBlock + OFFSET.enabled) == 1
end

--- Turns invulnerability on or off, installing the code caves on first use.
--- Returns false, with an error in the footer, if the flag cannot be confirmed.
function Cheats.setGodMode(enabled)
    if not installGodCaves() then return false end

    Memory.writeU32(godBlock + OFFSET.enabled, enabled and 1 or 0)
    if Cheats.isGodMode() ~= enabled then return Native.fail("God Mode: the flag did not stick in memory") end

    if enabled then refillPlayer() end
    local hint = hasAutoDetection() and "" or " - no auto-detection, use Lock To Damaged Target"
    State.setStatus((enabled and "God Mode ON" or "God Mode OFF") .. hint, enabled and not hasAutoDetection() and "warning" or "success")
    return true
end

--- Reports whether every hit currently kills what it touches, the hero excepted.
function Cheats.isOneShotKill()
    return godBlock ~= nil and Memory.readU32(godBlock + OFFSET.oneShot) == 1
end

--- Turns one shot kill on or off: any entity but the hero drops to zero health on its first damage.
--- Needs the hero to be identified; the flag is refused when the damage cave in memory predates it.
function Cheats.setOneShotKill(enabled)
    if not installGodCaves() then return false end
    if not hasFlag(FLAG_ONE_SHOT_CAVE) then
        return Native.fail("One shot kill: the damage code in memory is from an older build, restart the game")
    end

    Memory.writeU32(godBlock + OFFSET.oneShot, enabled and 1 or 0)
    if Cheats.isOneShotKill() ~= enabled then return Native.fail("One shot kill: the flag did not stick in memory") end

    local heroKnown = (Memory.readU32(godBlock + OFFSET.player) or 0) ~= 0
    if enabled and not heroKnown then
        State.setStatus("One shot kill ON, waiting for the hero to be identified: take a hit or use Lock To Damaged Target",
            "warning")
        return true
    end
    State.setStatus(enabled and "One shot kill ON" or "One shot kill OFF", "success")
    return true
end

--- Pins God Mode to the last entity that took damage.
function Cheats.lockToLastDamaged()
    if not installGodCaves() then return false end

    local last = Memory.readU32(godBlock + OFFSET.lastDamaged) or 0
    if last == 0 then
        State.setStatus("No entity has taken damage yet", "warning")
        return false
    end
    Memory.writeU32(godBlock + OFFSET.player, last)
    State.godLocked = true
    State.setStatus(string.format("God Mode locked to entity 0x%X", last), "success")
    return true
end

--- Returns God Mode to automatic player detection.
function Cheats.unlockGodTarget()
    State.godLocked = false
    State.setStatus("God Mode target released (automatic detection)", "info")
end

--- Refills the player's health to its maximum.
function Cheats.refillHealth()
    if not installGodCaves() then return false end
    if not refillPlayer() then
        return Native.fail("Health: player not identified yet, take a hit then use Lock To Damaged Target")
    end
    State.setStatus("Avatar health refilled", "success")
    return true
end

--- Patches the Toy Box editor check so the editor opens in every world.
function Cheats.unlockEditorEverywhere()
    local site = Memory.patternScan(EDITOR_PATTERN)
    if not site then
        State.setStatus("Toy Box editor: signature not found (already unlocked, or game version mismatch)", "warning")
        return false
    end
    if not Memory.patchBytes(site + EDITOR_PATCH_OFFSET, EDITOR_PATCH) then
        return Native.fail("Toy Box editor: memory patch failed")
    end

    State.editorUnlocked = true
    State.setStatus("Toy Box editor unlocked everywhere", "success")
    return true
end

--- Per-frame upkeep: finds the player, mirrors its health and keeps it full under God Mode.
function Cheats.onTick()
    if not godBlock then return end
    ticks = ticks + 1
    if ticks % TICK_INTERVAL ~= 0 then return end

    if hasAutoDetection() and not State.godLocked then
        local component = pickPlayerComponent()
        if component and component ~= Memory.readU32(godBlock + OFFSET.player) then
            Memory.writeU32(godBlock + OFFSET.player, component)
        end
    end

    local player = Memory.readU32(godBlock + OFFSET.player)
    if isHealthComponent(player) then
        State.playerHealth.current = Memory.readFloat(player + HEALTH_CURRENT)
        State.playerHealth.max = Memory.readFloat(player + HEALTH_MAX)
    end

    if Cheats.isGodMode() then refillPlayer() end
end

openBlock()

return Cheats
