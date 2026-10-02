local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Theme = Loader.load("ui.theme")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")

local Overlay = {}

local COLORS = Config.THEME
local FLAGS = Config.IMGUI

local DEFAULT_SCREEN_WIDTH = 1920
local SCREEN_REFRESH = 2
local SAMPLE_COUNT = 30
local GOOD_FPS = 55
local LOW_FPS = 30
local LOW_HEALTH_RATIO = 0.3
local SPEED_TOLERANCE = 0.01
local WINDOW_FLAGS = FLAGS.WINDOW_NO_TITLE_BAR + FLAGS.WINDOW_NO_RESIZE + FLAGS.WINDOW_NO_MOVE
    + FLAGS.WINDOW_NO_COLLAPSE + FLAGS.WINDOW_ALWAYS_AUTO_RESIZE
    + FLAGS.WINDOW_NO_FOCUS_ON_APPEARING + FLAGS.WINDOW_NO_INPUTS

local screenWidth = DEFAULT_SCREEN_WIDTH
local screenStamp = -SCREEN_REFRESH
local samples = {}
local cursor = 1
local filled = 0
local sum = 0

local function fpsColor(fps)
    if fps < LOW_FPS then return COLORS.ACCENT_RED end
    if fps < GOOD_FPS then return COLORS.ACCENT_GOLD end
    return COLORS.ACCENT_GREEN
end

local function drawLabeled(label, drawValue)
    ImGui.Text(label)
    ImGui.SameLine()
    drawValue()
end

local function drawHealth()
    local current, max = State.playerHealth.current, State.playerHealth.max
    if not (current and max) then
        Theme.textMuted("unknown")
        return
    end
    local color = (current < max * LOW_HEALTH_RATIO) and COLORS.ACCENT_RED or COLORS.ACCENT_GREEN
    Theme.textColored(color, string.format("%.0f / %.0f", current, max))
end

local function drawBadges()
    Theme.badge(Cheats.isGodMode() and "GOD ON" or "GOD OFF", Cheats.isGodMode() and "green" or "muted")
    ImGui.SameLine()

    local speed = SpeedHack.getSpeed()
    if math.abs(speed - 1.0) > SPEED_TOLERANCE then
        Theme.badge(string.format("x%.2f SPEED", speed), "gold")
    else
        Theme.badge("1.0x", "muted")
    end

    if Crabe.Camera.IsFreeCamActive() then
        ImGui.SameLine()
        Theme.badge("FREECAM", "cyan")
    end
    if State.editorUnlocked then
        ImGui.SameLine()
        Theme.badge("TBX", "purple")
    end
end

--- Records a frame time and refreshes the smoothed FPS over the last SAMPLE_COUNT frames.
function Overlay.update(dt)
    sum = sum - (samples[cursor] or 0) + dt
    samples[cursor] = dt
    cursor = cursor % SAMPLE_COUNT + 1
    filled = math.min(filled + 1, SAMPLE_COUNT)

    State.frameTime = dt
    State.fps = (sum > 0) and filled / sum or 0
end

--- Draws the telemetry window in the top-right corner of the screen.
function Overlay.render()
    if State.gameClock - screenStamp >= SCREEN_REFRESH then
        screenStamp = State.gameClock
        screenWidth = Native.poll(Game.ScreenSize) or DEFAULT_SCREEN_WIDTH
    end
    local left = screenWidth - Config.UI.OVERLAY_WIDTH - Config.UI.OVERLAY_MARGIN

    ImGui.SetNextWindowPos(left, Config.UI.OVERLAY_MARGIN, FLAGS.COND_ALWAYS)
    ImGui.SetNextWindowSize(Config.UI.OVERLAY_WIDTH, 0, FLAGS.COND_ONCE)

    local visible = ImGui.Begin(Config.UI.OVERLAY_TITLE, true, WINDOW_FLAGS)
    if visible then
        Theme.textCyan("INFINITY RUNTIME MONITOR")
        ImGui.Separator()

        drawLabeled("Performance:", function()
            Theme.textColored(fpsColor(State.fps), string.format("%.1f FPS", State.fps))
            ImGui.SameLine()
            Theme.textMuted(string.format("(%.2f ms)", State.frameTime * 1000.0))
        end)
        drawLabeled("Hero:", function()
            Theme.textGold(string.format("%s [SKU %s]", State.avatarName, tostring(State.avatarSku)))
        end)
        drawLabeled("Health:", drawHealth)
        drawLabeled("Lua memory:", function()
            Theme.textMuted(string.format("%.2f MB", collectgarbage("count") / 1024.0))
        end)

        ImGui.Separator()
        drawBadges()
    end
    ImGui.End()
end

return Overlay
