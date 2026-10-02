local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local WorldModule = {}

local VIDEO_REFRESH = 2

local videoStates = {}
local videoStamp = -VIDEO_REFRESH

WorldModule.VIDEO_OPTIONS = {
    { key = "Bloom", label = "Bloom Glow" },
    { key = "SSAO", label = "SSAO Ambient Occlusion" },
    { key = "FXAA", label = "FXAA Anti-Aliasing" },
    { key = "MotionBlur", label = "Motion Blur" },
    { key = "DepthOfField", label = "Depth of Field" },
}

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

return WorldModule
