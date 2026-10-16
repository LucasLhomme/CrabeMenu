local Loader = ...
local State = Loader.load("core.state")
local Items = Loader.load("ui.items")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")
local NoFall = Loader.load("modules.nofall")
local Stealth = Loader.load("modules.stealth")

local SPEED_LABELS = {}
for index, value in ipairs(SpeedHack.PRESETS) do SPEED_LABELS[index] = string.format("x%.2f", value) end

local function speedIndex()
    local current, best, bestGap = SpeedHack.getSpeed(), 1, math.huge
    for index, value in ipairs(SpeedHack.PRESETS) do
        local gap = math.abs(value - current)
        if gap < bestGap then best, bestGap = index, gap end
    end
    return best
end

local NoFallLabels = {}
for index, mode in ipairs(NoFall.MODES) do NoFallLabels[index] = mode.label end

local function toggleGodTarget()
    if State.godLocked then Cheats.unlockGodTarget() else Cheats.lockToLastDamaged() end
end

local PLAYER_SPEED_LABELS = {}
for index, value in ipairs(SpeedHack.PLAYER_PRESETS) do PLAYER_SPEED_LABELS[index] = string.format("x%.1f", value) end

local function playerSpeedIndex()
    local current, best, bestGap = SpeedHack.getPlayerSpeed(), 1, math.huge
    for index, value in ipairs(SpeedHack.PLAYER_PRESETS) do
        local gap = math.abs(value - current)
        if gap < bestGap then best, bestGap = index, gap end
    end
    return best
end

local PLAYER_SPEED_ITEMS = {
    Items.choice("Hero speed", PLAYER_SPEED_LABELS, playerSpeedIndex,
        function(index) SpeedHack.setPlayerSpeed(SpeedHack.PLAYER_PRESETS[index]) end,
        "Makes only your hero run faster; enemies and the world keep their pace"),
}
local NO_PLAYER_SPEED_ITEMS = {
    Items.info("Hero speed", "Unavailable", "Needs a CrabeLoader with per-actor speed"),
}

local SPEED_ITEMS = {
    Items.choice("Game speed", SPEED_LABELS, speedIndex, function(index) SpeedHack.setSpeed(SpeedHack.PRESETS[index]) end,
        "Slow motion or turbo for the whole game"),
    Items.action("Normal speed", SpeedHack.reset, "Puts the game back to x1.00"),
}
local NO_SPEED_ITEMS = {
    Items.info("Game speed", "Unavailable", "Needs Crabe.GameSpeed, which this CrabeLoader build does not provide"),
}

local HEAD = {
    Items.section("Health"),
    Items.toggle("God mode", Cheats.isGodMode, Cheats.setGodMode, "Your health refills every time you take damage"),
    Items.action(function() return State.godLocked and "Release locked target" or "Lock to last damaged target" end,
        toggleGodTarget, "Pins god mode to whoever was hit last, if it picked the wrong one"),
    Items.action("Refill health", Cheats.refillHealth, "Fills your health bar back up"),
    Items.toggle("Stealth", Stealth.isEnabled, Stealth.setEnabled,
        "Enemies stop targeting you; the few that always aim at the hero may still react"),
    Items.toggle("One shot kill", Cheats.isOneShotKill, Cheats.setOneShotKill,
        "Every hit kills what it touches, bosses and allies included; only your hero keeps its health"),
    Items.toggle("No fall", NoFall.isEnabled, NoFall.setEnabled,
        "Hits no longer knock your hero down; pair it with God mode so health stays full"),
    Items.choice("No fall mode", NoFallLabels, NoFall.getMode, NoFall.setMode,
        "No reaction ignores every hit; Flinch only keeps the small stagger but never falls"),
    Items.section("Time"),
}
local TAIL = {
    Items.section("Toy Box"),
    Items.action(function() return State.editorUnlocked and "Editor unlocked everywhere" or "Unlock editor everywhere" end,
        Cheats.unlockEditorEverywhere, "Lets you open the Toy Box editor in every world"),
}

local function concat(...)
    local list = {}
    for _, part in ipairs({ ... }) do
        for _, item in ipairs(part) do list[#list + 1] = item end
    end
    return list
end

local variants = {}
for _, clock in ipairs({ true, false }) do
    for _, hero in ipairs({ true, false }) do
        variants[tostring(clock) .. tostring(hero)] = concat(HEAD,
            clock and SPEED_ITEMS or NO_SPEED_ITEMS,
            hero and PLAYER_SPEED_ITEMS or NO_PLAYER_SPEED_ITEMS,
            TAIL)
    end
end

local function pageItems()
    return variants[tostring(SpeedHack.isAvailable()) .. tostring(SpeedHack.isPlayerSpeedAvailable())]
end

return {
    title = "Cheats",
    items = pageItems,
}
