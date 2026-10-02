local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Settings = Loader.load("core.settings")
local Items = Loader.load("ui.items")
local WorldModule = Loader.load("modules.world")

local SIDES = { "left", "right" }
local SIDE_LABELS = { "Left", "Right" }

local SCALE_LABELS = {}
for index, entry in ipairs(Config.SCALES) do SCALE_LABELS[index] = entry.label end

local function setSide(index)
    State.menuSide = SIDES[index]
    Settings.save()
end

local function setScale(index)
    State.scaleIndex = index
    Settings.save()
end

local function setOverlay(on)
    if on == State.isOverlayOpen then return end
    State.toggleOverlay()
    Settings.save()
end

local function videoToggle(option)
    local function isOn() return WorldModule.isVideoEnabled(option.key) == true end
    return Items.toggle(option.label, isOn, function(on)
        if on ~= isOn() then WorldModule.toggleVideoOption(option) end
    end, "Turns " .. option.label .. " on or off and saves the game settings")
end

local ITEMS = {
    Items.section("Menu"),
    Items.choice("Menu side", SIDE_LABELS, function() return (State.menuSide == "right") and 2 or 1 end, setSide,
        "Which side of the screen the menu sits on"),
    Items.choice("Menu size", SCALE_LABELS, function() return State.scaleIndex end, setScale,
        "Makes the whole menu smaller or bigger"),
    Items.toggle("Runtime overlay (F6)", function() return State.isOverlayOpen end, setOverlay,
        "Shows FPS, hero, health and active cheats in a corner"),
    Items.section("Video"),
}
for _, option in ipairs(WorldModule.VIDEO_OPTIONS) do ITEMS[#ITEMS + 1] = videoToggle(option) end

ITEMS[#ITEMS + 1] = Items.section("About")
ITEMS[#ITEMS + 1] = Items.info(Config.NAME, "v" .. Config.VERSION, "Made by " .. Config.AUTHOR)
ITEMS[#ITEMS + 1] = Items.info("Keyboard", "F5 menu  \194\183  F6 overlay", "Insert opens the CrabeLoader console")
ITEMS[#ITEMS + 1] = Items.info("Controller", "RB + \226\134\144 menu", "Hold RB and press left on the D-pad")

return {
    title = "Settings",
    items = function() return ITEMS end,
}
