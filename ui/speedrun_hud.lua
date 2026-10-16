local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Theme = Loader.load("ui.theme")
local Speedrun = Loader.load("modules.speedrun")
local SpeedHack = Loader.load("modules.speedhack")
local Avatar = Loader.load("modules.avatar")

local SpeedrunHud = {}

local FONT, ALIGN = Theme.FONT, Theme.ALIGN
local DESIGN_HEIGHT = Config.LAYOUT.DESIGN_HEIGHT
local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1920, 1080
local WIDTH = 300
local HEADER_HEIGHT = 30
local TIMER_HEIGHT = 58
local ROW_HEIGHT = 26
local PADDING = 14
local MARGIN = 20
local POSITION_INTERVAL = 0.1
local SPEED_TOLERANCE = 0.01

SpeedrunHud.CORNERS = { "Top left", "Top right", "Bottom left", "Bottom right" }

SpeedrunHud.ROWS = {
    { key = "world", label = "World name" },
    { key = "splits", label = "Splits" },
    { key = "position", label = "Hero position" },
    { key = "speed", label = "Hero speed" },
}

local positionText = "-"
local sinceRead = POSITION_INTERVAL

local function worldName()
    local world = Native.poll(Game.CurrentWorld)
    return type(world) == "string" and world or "-"
end

local function readPosition()
    local handle = Avatar.handle()
    if not handle then
        positionText = "-"
        return
    end

    local x, y, z = Native.poll(Game.ActorPosition, handle)
    positionText = x and string.format("%.1f  %.1f  %.1f", x, y, z) or "-"
end

local function rows()
    local hidden = State.hudHidden
    local list = {}
    if not hidden.world then list[#list + 1] = { "World", worldName(), "white" } end
    if not hidden.splits then
        for _, split in ipairs(Speedrun.recentSplits()) do
            list[#list + 1] = { "Split " .. split.number, split.text, "cyan" }
        end
    end
    if not hidden.position then list[#list + 1] = { "Position", positionText, "muted" } end
    local speed = SpeedHack.getPlayerSpeed()
    if not hidden.speed and math.abs(speed - 1.0) > SPEED_TOLERANCE then
        list[#list + 1] = { "Hero speed", string.format("x%.2f", speed), "gold" }
    end
    return list
end

local function origin(corner, screenWidth, screenHeight, height)
    local right = (corner == 2) or (corner == 4)
    local bottom = (corner == 3) or (corner == 4)
    local x = right and (screenWidth - MARGIN - WIDTH) or MARGIN
    local y = bottom and (screenHeight - MARGIN - height) or MARGIN
    return x, y
end

--- Refreshes the hero position a few times a second while the HUD is shown.
function SpeedrunHud.update(dt)
    if not State.isSpeedrunHudOpen or State.hudHidden.position then return end
    sinceRead = sinceRead + dt
    if sinceRead < POSITION_INTERVAL then return end
    sinceRead = 0
    readPosition()
end

--- Draws the speedrun panel in the chosen corner: stopwatch, world, splits, position and hero speed.
function SpeedrunHud.render()
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or screenWidth <= 0 then screenWidth, screenHeight = FALLBACK_WIDTH, FALLBACK_HEIGHT end
    local factor = screenHeight / DESIGN_HEIGHT
    Theme.beginFrame(factor, 0, 0, 1)

    local list = rows()
    local height = HEADER_HEIGHT + TIMER_HEIGHT + #list * ROW_HEIGHT + (#list > 0 and 10 or 0)
    local x, y = origin(State.hudCorner, screenWidth / factor, screenHeight / factor, height)

    Theme.gradient(x, y, WIDTH, HEADER_HEIGHT, Theme.color("royal", 245), Theme.color("violet", 245), true)
    Theme.rowText(x + PADDING, y, HEADER_HEIGHT, "SPEEDRUN", Theme.color("white"), 14, ALIGN.LEFT, WIDTH, FONT.BODY)
    Theme.rect(x, y + HEADER_HEIGHT - 2, WIDTH, 2, Theme.color("gold"))

    local top = y + HEADER_HEIGHT
    Theme.rect(x, top, WIDTH, height - HEADER_HEIGHT, Theme.color("panel", 215))
    local timerColor = Speedrun.isTimerRunning() and "gold" or "white"
    Theme.rowText(x, top, TIMER_HEIGHT, Speedrun.timerText(), Theme.color(timerColor), 36, ALIGN.CENTER, WIDTH, FONT.BODY)

    for index, row in ipairs(list) do
        local rowY = top + TIMER_HEIGHT + (index - 1) * ROW_HEIGHT
        Theme.rowText(x + PADDING, rowY, ROW_HEIGHT, row[1], Theme.color("muted"), 15, ALIGN.LEFT, 110)
        Theme.rowText(x + 110, rowY, ROW_HEIGHT, row[2], Theme.color(row[3]), 15, ALIGN.RIGHT, WIDTH - 110 - PADDING)
    end
end

return SpeedrunHud
