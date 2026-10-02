local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")

local Overlay = {}

local FONT, ALIGN = Theme.FONT, Theme.ALIGN
local DESIGN_HEIGHT = Config.LAYOUT.DESIGN_HEIGHT
local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1920, 1080
local HEADER_HEIGHT = 30
local ROW_HEIGHT = 26
local BADGE_HEIGHT = 34
local BADGE_WIDTH = 64
local PADDING = 14
local SAMPLE_COUNT = 30
local GOOD_FPS = 55
local LOW_FPS = 30
local LOW_HEALTH_RATIO = 0.3
local SPEED_TOLERANCE = 0.01

local samples = {}
local cursor = 1
local filled = 0
local sum = 0

local function fpsColor()
    if State.fps < LOW_FPS then return "red" end
    if State.fps < GOOD_FPS then return "gold" end
    return "green"
end

local function healthText()
    local current, max = State.playerHealth.current, State.playerHealth.max
    if not (current and max) then return "unknown", "muted" end
    local color = (current < max * LOW_HEALTH_RATIO) and "red" or "green"
    return string.format("%.0f / %.0f", current, max), color
end

local function badges()
    local list = {}
    if Cheats.isGodMode() then list[#list + 1] = { "GOD", "green" } end

    local speed = SpeedHack.getSpeed()
    if math.abs(speed - 1.0) > SPEED_TOLERANCE then list[#list + 1] = { string.format("x%.2f", speed), "gold" } end
    if Crabe.Camera.IsFreeCamActive() then list[#list + 1] = { "CAM", "cyan" } end
    if State.editorUnlocked then list[#list + 1] = { "TBX", "violet" } end
    return list
end

local function drawRow(x, y, w, label, value, color)
    Theme.rowText(x + PADDING, y, ROW_HEIGHT, label, Theme.color("muted"), 15, ALIGN.LEFT, 110)
    Theme.rowText(x + 110, y, ROW_HEIGHT, value, Theme.color(color), 15, ALIGN.RIGHT, w - 110 - PADDING)
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

--- Draws the telemetry card in the top corner the menu is not using.
function Overlay.render()
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or screenWidth <= 0 then screenWidth, screenHeight = FALLBACK_WIDTH, FALLBACK_HEIGHT end
    local factor = screenHeight / DESIGN_HEIGHT
    Theme.beginFrame(factor, 0, 0, 1)

    local w = Config.UI.OVERLAY_WIDTH
    local margin = Config.UI.OVERLAY_MARGIN
    local onLeft = State.isMenuOpen and State.menuSide == "right"
    local x = onLeft and margin or (screenWidth / factor - margin - w)
    local y = margin

    local health, healthColor = healthText()
    local rows = {
        { "Performance", string.format("%.0f FPS  (%.1f ms)", State.fps, State.frameTime * 1000), fpsColor() },
        { "Hero", State.avatarName, "white" },
        { "Health", health, healthColor },
        { "Lua memory", string.format("%.2f MB", collectgarbage("count") / 1024), "muted" },
    }
    local active = badges()
    local bodyHeight = #rows * ROW_HEIGHT + 8 + (#active > 0 and BADGE_HEIGHT or 0)

    Theme.gradient(x, y, w, HEADER_HEIGHT, Theme.color("royal", 245), Theme.color("violet", 245), true)
    Theme.rowText(x + PADDING, y, HEADER_HEIGHT, "INFINITY MONITOR", Theme.color("white"), 14, ALIGN.LEFT, w, FONT.BODY)
    Theme.rowText(x, y, HEADER_HEIGHT, "\226\136\158", Theme.color("ice", 170), 20, ALIGN.RIGHT, w - PADDING)
    Theme.rect(x, y + HEADER_HEIGHT - 2, w, 2, Theme.color("gold"))

    local top = y + HEADER_HEIGHT
    Theme.rect(x, top, w, bodyHeight, Theme.color("panel", 215))
    for index, row in ipairs(rows) do
        drawRow(x, top + 4 + (index - 1) * ROW_HEIGHT, w, row[1], row[2], row[3])
    end

    local by = top + 4 + #rows * ROW_HEIGHT + 4
    for index, badge in ipairs(active) do
        local bx = x + PADDING + (index - 1) * (BADGE_WIDTH + 8)
        Theme.rect(bx, by, BADGE_WIDTH, 22, Theme.color(badge[2], 60), 11)
        Theme.rect(bx, by, BADGE_WIDTH, 22, Theme.color(badge[2], 220), 11, 1)
        Theme.rowText(bx, by, 22, badge[1], Theme.color(badge[2]), 13, ALIGN.CENTER, BADGE_WIDTH)
    end
end

return Overlay
