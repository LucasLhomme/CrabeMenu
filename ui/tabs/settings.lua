local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")
local WorldModule = Loader.load("modules.world")

local function drawOverlay()
    Theme.subHeader("Runtime overlay (F6)")
    local label = State.isOverlayOpen and "Disable overlay" or "Enable overlay"
    if Theme.button(label, 200) then State.toggleOverlay() end
end

local function drawVideo()
    Theme.subHeader("Video")
    for _, option in ipairs(WorldModule.VIDEO_OPTIONS) do
        local enabled = WorldModule.isVideoEnabled(option.key)
        local state = (enabled == nil) and "?" or (enabled and "ON" or "OFF")
        if Theme.button(string.format("%s: %s", option.label, state), 260) then
            WorldModule.toggleVideoOption(option)
        end
    end
end

local function drawAbout()
    Theme.subHeader("About")
    Theme.textMuted(string.format("%s v%s by %s", Config.NAME, Config.VERSION, Config.AUTHOR))
    Theme.textMuted("F5: menu | F6: overlay | Insert: CrabeLoader console")
end

local function render()
    Theme.header("Settings")
    drawOverlay()
    drawVideo()
    drawAbout()
end

return { title = "Settings", render = render }
