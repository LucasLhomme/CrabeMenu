local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local WorldModule = {}

local VIDEO_REFRESH = 2

local videoStates = {}
local videoStamp = -VIDEO_REFRESH

WorldModule.PLAYSETS = {
    { key = "Asgard", label = "Thor: Asgard World" },
    { key = "Avengers", label = "Marvel: The Avengers" },
    { key = "Brave", label = "Brave: Forest Highlands" },
    { key = "Empire", label = "Star Wars: Rise Against the Empire" },
    { key = "Guardians", label = "Guardians of the Galaxy" },
    { key = "InsideOut", label = "Inside Out: Imagination Land" },
    { key = "Kyln", label = "Marvel: Escape from the Kyln" },
    { key = "PlaysetX", label = "Star Wars: The Force Awakens" },
    { key = "Speedway", label = "Toy Box Speedway" },
    { key = "SpiderMan", label = "Spider-Man: Manhattan" },
    { key = "Stitch", label = "Lilo & Stitch: Tropical Rescue" },
    { key = "Takeover", label = "Toy Box Takeover" },
    { key = "TheCloneWars", label = "Star Wars: Twilight of the Republic" },
}

WorldModule.VIDEO_OPTIONS = {
    { key = "Bloom", label = "Bloom Glow" },
    { key = "SSAO", label = "SSAO Ambient Occlusion" },
    { key = "FXAA", label = "FXAA Anti-Aliasing" },
    { key = "MotionBlur", label = "Motion Blur" },
    { key = "DepthOfField", label = "Depth of Field" },
}

--- Unlocks one Play Set; the status is only set by the caller when announce is true.
function WorldModule.unlockPlayset(playset, announce)
    if not Native.run("Game.UnlockPlayset", Game.UnlockPlayset, playset.key) then return false end
    if announce then State.setStatus("Unlocked Play Set: " .. playset.label, "success") end
    return true
end

--- Unlocks every Play Set and reports how many succeeded.
function WorldModule.unlockAllPlaysets()
    local unlocked = 0
    for _, playset in ipairs(WorldModule.PLAYSETS) do
        if WorldModule.unlockPlayset(playset, false) then unlocked = unlocked + 1 end
    end

    local total = #WorldModule.PLAYSETS
    local message = string.format("Unlocked %d / %d Play Sets", unlocked, total)
    if unlocked == total then
        State.setStatus(message, "success")
    elseif unlocked > 0 then
        State.setStatus(message, "warning")
    else
        Native.fail(message)
    end
    return unlocked == total
end

--- Returns whether a video option is enabled, or nil if it cannot be read.
--- The engine is queried at most every VIDEO_REFRESH seconds, not every frame.
function WorldModule.isVideoEnabled(key)
    if State.gameClock - videoStamp >= VIDEO_REFRESH then
        videoStamp = State.gameClock
        for _, option in ipairs(WorldModule.VIDEO_OPTIONS) do
            videoStates[option.key] = Native.poll(Game.VideoToggles[option.key].get)
        end
    end
    return videoStates[key]
end

--- Flips a video option, applies it and saves the settings.
function WorldModule.toggleVideoOption(option)
    local toggle = Game.VideoToggles[option.key]
    local ok, current = Native.run("Game.VideoToggles." .. option.key .. ".get", toggle.get)
    if not ok then return false end

    local target = not current
    if not Native.run("Game.VideoToggles." .. option.key .. ".set", toggle.set, target) then return false end
    if not Native.run("Game.ApplyVideoSettings", Game.ApplyVideoSettings) then return false end
    if not Native.run("Game.SaveSettings", Game.SaveSettings) then return false end

    videoStamp = -VIDEO_REFRESH
    State.setStatus(option.label .. (target and " enabled" or " disabled"), "info")
    return true
end

--- Returns the skydome themes the loader knows.
function WorldModule.getThemes()
    return Native.poll(Game.ListThemes) or {}
end

--- Applies a skydome theme to the loaded world.
function WorldModule.applyTheme(theme)
    local ok, applied = Native.run("Game.SetTheme", Game.SetTheme, theme.id)
    if not ok then return false end
    if not applied then return Native.fail("Skydome: the theme native is missing, load a world first") end

    State.setStatus("Applied skydome: " .. theme.label, "success")
    return true
end

return WorldModule
