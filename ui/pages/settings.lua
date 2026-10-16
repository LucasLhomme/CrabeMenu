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

local function setLockControls(on)
    State.lockControls = (on == true)
    if State.applyCapture then State.applyCapture() end
    Settings.save()
end

local RESOLUTIONS = {
    { label = "1280x720 (720p)",  w = 1280, h = 720 },
    { label = "1280x800 (Deck)",  w = 1280, h = 800 },
    { label = "1600x900",         w = 1600, h = 900 },
    { label = "1920x1080 (1080p)", w = 1920, h = 1080 },
    { label = "1920x1200",        w = 1920, h = 1200 },
    { label = "2560x1080 (21:9)", w = 2560, h = 1080 },
    { label = "2560x1440 (1440p)", w = 2560, h = 1440 },
    { label = "3440x1440 (UW)",   w = 3440, h = 1440 },
    { label = "3840x1600 (UW)",   w = 3840, h = 1600 },
    { label = "3840x2160 (4K UHD)", w = 3840, h = 2160 },
    { label = "5120x1440 (SuperUW)", w = 5120, h = 1440 },
    { label = "5120x2160 (5K2K)", w = 5120, h = 2160 },
}

local RES_LABELS = {}
for i, r in ipairs(RESOLUTIONS) do RES_LABELS[i] = r.label end

-- The engine cannot resize its render targets while running, so the choice is
-- only recorded: it shows here at once, and takes effect at the next launch.
local pendingResolution

local function getResIndex()
    local curW, curH = Game.GetResolution()
    local wantW, wantH = curW, curH
    if pendingResolution then wantW, wantH = pendingResolution.w, pendingResolution.h end
    for i, r in ipairs(RESOLUTIONS) do
        if r.w == wantW and r.h == wantH then return i end
    end
    return 4
end

local function setResIndex(index)
    local target = RESOLUTIONS[index]
    if not target then return end
    Game.SetResolution(target.w, target.h)
    pendingResolution = target
    Crabe.write(string.format("[CrabeMenu] Resolution saved for next launch: %s (%dx%d)", target.label, target.w, target.h))
end

-- 0 is "no cap": the game never limits its own frame rate on PC.
local FRAME_LIMITS = { 0, 30, 45, 60, 75, 90, 120, 144, 160, 180 }
local FRAME_LIMIT_LABELS = {}
for i, fps in ipairs(FRAME_LIMITS) do
    FRAME_LIMIT_LABELS[i] = (fps == 0) and "Unlimited" or (fps .. " FPS")
end

local function getFrameLimitIndex()
    local current = Crabe.GetFrameLimit()
    for i, fps in ipairs(FRAME_LIMITS) do
        if fps == current then return i end
    end
    return 1
end

local function setFrameLimitIndex(index)
    local fps = FRAME_LIMITS[index]
    if fps == nil then return end
    Crabe.SetFrameLimit(fps)
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
    Items.toggle("Lock in-game controls", function() return State.lockControls end, setLockControls,
        "Locks in-game movement and actions while the menu is open"),
    Items.toggle("Runtime overlay (F6)", function() return State.isOverlayOpen end, setOverlay,
        "Shows FPS, hero, health and active cheats in a corner"),
    Items.section("Video"),
    Items.choice("Resolution", RES_LABELS, getResIndex, setResIndex,
        "Takes effect the next time the game starts (4K UHD, ultrawide, Steam Deck)"),
    Items.choice("Frame rate limit", FRAME_LIMIT_LABELS, getFrameLimitIndex, setFrameLimitIndex,
        "Caps the frame rate at once; saved for the next launches"),
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
