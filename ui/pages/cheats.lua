local Loader = ...
local State = Loader.load("core.state")
local Items = Loader.load("ui.items")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")

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

local function toggleGodTarget()
    if State.godLocked then Cheats.unlockGodTarget() else Cheats.lockToLastDamaged() end
end

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

local withSpeed = concat(HEAD, SPEED_ITEMS, TAIL)
local withoutSpeed = concat(HEAD, NO_SPEED_ITEMS, TAIL)

return {
    title = "Cheats",
    items = function() return SpeedHack.isAvailable() and withSpeed or withoutSpeed end,
}
