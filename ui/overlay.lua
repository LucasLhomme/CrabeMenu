local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")
local Speedrun = Loader.load("modules.speedrun")
local Stealth = Loader.load("modules.stealth")

local Overlay = {}

local FONT, ALIGN = Theme.FONT, Theme.ALIGN
local DESIGN_HEIGHT = Config.LAYOUT.DESIGN_HEIGHT
local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1920, 1080
local HEADER_HEIGHT = 28
local ROW_HEIGHT = 22
local BADGE_HEIGHT = 32
local BADGE_WIDTH = 64
local PADDING = 12
local SAMPLE_COUNT = 30
local GOOD_FPS = 55
local LOW_FPS = 30
local LOW_HEALTH_RATIO = 0.3
local SPEED_TOLERANCE = 0.01

Overlay.ROWS = {
    { key = "zone", label = "Active Zone" },
    { key = "avatar", label = "Hero / Avatar" },
    { key = "locomotion", label = "Locomotion Mode" },
    { key = "camera", label = "Camera / Spline" },
    { key = "pos", label = "Position (X, Y, Z)" },
    { key = "speed", label = "Swim Speed & Tier" },
    { key = "velocity", label = "Velocity Vector" },
    { key = "submersion", label = "Water Submersion" },
    { key = "raycast", label = "Water Ceiling" },
    { key = "cutscene", label = "Choreographies" },
    { key = "textures", label = "Missing Textures" },
    { key = "control", label = "Control Status" },
}

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

local function parseDevToolkitTelemetry(raw)
    if not raw or raw == "" then return nil end

    local x = tonumber(raw:match('"x"%s*:%s*([%-0-9%.]+)'))
    if not x then return nil end

    local rayHit = raw:match('"rayHit"%s*:%s*true') ~= nil
    local rayX = tonumber(raw:match('"rayX"%s*:%s*([%-0-9%.]+)')) or 0
    local rayY = tonumber(raw:match('"rayY"%s*:%s*([%-0-9%.]+)')) or 0
    local rayZ = tonumber(raw:match('"rayZ"%s*:%s*([%-0-9%.]+)')) or 0
    local rayNx = tonumber(raw:match('"rayNx"%s*:%s*([%-0-9%.]+)')) or 0
    local rayNy = tonumber(raw:match('"rayNy"%s*:%s*([%-0-9%.]+)')) or 0
    local rayNz = tonumber(raw:match('"rayNz"%s*:%s*([%-0-9%.]+)')) or 0
    local rayDist = tonumber(raw:match('"rayDist"%s*:%s*([%-0-9%.]+)')) or 0
    local raySurf = tonumber(raw:match('"raySurf"%s*:%s*([%-0-9]+)')) or 0
    local rayObj = tonumber(raw:match('"rayObj"%s*:%s*([%-0-9]+)')) or 0

    if rayHit then
        State.lastRayHit = {
            x = rayX, y = rayY, z = rayZ,
            nx = rayNx, ny = rayNy, nz = rayNz,
            dist = rayDist, surf = raySurf, obj = rayObj,
        }
    else
        State.lastRayHit = nil
    end

    local coordType = tonumber(raw:match('"coordType"%s*:%s*([%-0-9]+)')) or 0
    local vx = tonumber(raw:match('"vx"%s*:%s*([%-0-9%.]+)')) or 0
    local vy = tonumber(raw:match('"vy"%s*:%s*([%-0-9%.]+)')) or 0
    local vz = tonumber(raw:match('"vz"%s*:%s*([%-0-9%.]+)')) or 0

    return {
        handle = tonumber(raw:match('"handle"%s*:%s*([%-0-9]+)')) or 0,
        name = raw:match('"name"%s*:%s*"([^"]*)"') or "",
        submersion = 0,
        submerged = 0,
        waterSurfaceY = 10000,
        coordType = coordType,
        splineHandle = tonumber(raw:match('"splineHandle"%s*:%s*([%-0-9]+)')) or 0,
        playerControl = 1,
        camMode = (raw:match('"camValid"%s*:%s*true') ~= nil) and "EngineCamera" or "Offline",
        camX = tonumber(raw:match('"camX"%s*:%s*([%-0-9%.]+)')) or 0,
        camY = tonumber(raw:match('"camY"%s*:%s*([%-0-9%.]+)')) or 0,
        camZ = tonumber(raw:match('"camZ"%s*:%s*([%-0-9%.]+)')) or 0,
        fov = tonumber(raw:match('"fov"%s*:%s*([%-0-9%.]+)')) or 60.0,
        choPlaying = 0,
        choLoading = 0,
        choCount = 0,
        x = x,
        y = tonumber(raw:match('"y"%s*:%s*([%-0-9%.]+)')) or 0,
        z = tonumber(raw:match('"z"%s*:%s*([%-0-9%.]+)')) or 0,
        vx = vx, vy = vy, vz = vz,
        rayHit = rayHit,
        rayX = rayX, rayY = rayY, rayZ = rayZ,
        rayDist = rayDist, raySurf = raySurf, rayObj = rayObj,
    }
end

local function readTelemetry()
    if Crabe and Crabe.Plugins and Crabe.Plugins.get then
        local raw = Crabe.Plugins.get("dev_toolkit.telemetry")
        local live = parseDevToolkitTelemetry(raw)
        if live then
            return live
        end
    end

    local f = io.open("mods/update_106/telemetry.json", "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    if not s or s == "" then return nil end

    local handle = tonumber(s:match('"handle":%s*([%-0-9]+)'))
    local submersion = tonumber(s:match('"submersion":%s*([%-0-9%.]+)'))
    local submerged = tonumber(s:match('"submerged":%s*([%-0-9]+)'))
    local waterSurfaceY = tonumber(s:match('"waterSurfaceY":%s*([%-0-9%.]+)'))
    local coordType = tonumber(s:match('"coordType":%s*([%-0-9]+)'))
    local splineHandle = tonumber(s:match('"splineHandle":%s*([%-0-9]+)'))
    local playerControl = tonumber(s:match('"playerControl":%s*([%-0-9]+)'))
    local camMode = s:match('"camMode":%s*"([^"]+)"')
    local camX = tonumber(s:match('"camX":%s*([%-0-9%.]+)'))
    local camY = tonumber(s:match('"camY":%s*([%-0-9%.]+)'))
    local camZ = tonumber(s:match('"camZ":%s*([%-0-9%.]+)'))
    local choPlaying = tonumber(s:match('"choPlaying":%s*([%-0-9]+)'))
    local choLoading = tonumber(s:match('"choLoading":%s*([%-0-9]+)'))
    local choCount = tonumber(s:match('"choCount":%s*([%-0-9]+)'))
    local x = tonumber(s:match('"x":%s*([%-0-9%.]+)'))
    local y = tonumber(s:match('"y":%s*([%-0-9%.]+)'))
    local z = tonumber(s:match('"z":%s*([%-0-9%.]+)'))
    local vx = tonumber(s:match('"vx":%s*([%-0-9%.]+)'))
    local vy = tonumber(s:match('"vy":%s*([%-0-9%.]+)'))
    local vz = tonumber(s:match('"vz":%s*([%-0-9%.]+)'))

    if not x then return nil end
    return {
        handle = handle or 0,
        submersion = submersion or 0,
        submerged = submerged or 0,
        waterSurfaceY = waterSurfaceY or 10000,
        coordType = coordType or 0,
        splineHandle = splineHandle or 0,
        playerControl = playerControl or 0,
        camMode = camMode or "Engine3D",
        camX = camX or 0, camY = camY or 0, camZ = camZ or 0,
        fov = 60.0,
        choPlaying = choPlaying or 0,
        choLoading = choLoading or 0,
        choCount = choCount or 0,
        x = x, y = y, z = z,
        vx = vx or 0, vy = vy or 0, vz = vz or 0,
        rayHit = false, rayX = 0, rayY = 0, rayZ = 0, rayDist = 0, raySurf = 0,
    }
end

local function badges()
    local list = {}
    if Cheats.isGodMode() then list[#list + 1] = { "GOD", "green" } end
    if Cheats.isOneShotKill() then list[#list + 1] = { "1HIT", "red" } end
    if Stealth.isEnabled() then list[#list + 1] = { "STLH", "violet" } end

    local speed = SpeedHack.getSpeed()
    if math.abs(speed - 1.0) > SPEED_TOLERANCE then list[#list + 1] = { string.format("x%.2f", speed), "gold" } end
    if Crabe.Camera and Crabe.Camera.IsFreeCamActive and Crabe.Camera.IsFreeCamActive() then
        list[#list + 1] = { "CAM", "cyan" }
    end
    if State.editorUnlocked then list[#list + 1] = { "TBX", "violet" } end
    return list
end

local function drawRow(x, y, w, label, value, color, labelW)
    local lw = labelW or 130
    Theme.rowText(x + PADDING, y, ROW_HEIGHT, label, Theme.color("muted"), 14, ALIGN.LEFT, lw)
    Theme.rowText(x + lw, y, ROW_HEIGHT, value, Theme.color(color or "white"), 14, ALIGN.RIGHT, w - lw - PADDING)
end

function Overlay.update(dt)
    sum = sum - (samples[cursor] or 0) + dt
    samples[cursor] = dt
    cursor = cursor % SAMPLE_COUNT + 1
    filled = math.min(filled + 1, SAMPLE_COUNT)

    State.frameTime = dt
    State.fps = (sum > 0) and filled / sum or 0
end

local function getMissingTexturesInfo()
    local f = io.open("mods/update_106/diagnostics.jsonl", "r")
    if not f then return "0 (None)", "green" end
    -- Read up to the last 8KB to find recent missing textures
    local len = f:seek("end")
    local readSize = math.min(len, 8192)
    f:seek("set", len - readSize)
    local chunk = f:read("*a")
    f:close()

    local count = 0
    local lastTex = nil
    for tex in chunk:gmatch('Asset not found: textures/([a-f0-9]+)%.tbody') do
        count = count + 1
        lastTex = tex
    end

    if count == 0 then
        return "0 (All Loaded)", "green"
    else
        return string.format("%d (Last: %s)", count, lastTex:sub(1, 8) .. ".."), "gold"
    end
end

--- Draws the Dev Mode telemetry inspector on the top-left of the screen
local function renderDevInspector(factor)
    local x = 24
    local y = 24
    local w = 480

    local telem = readTelemetry()

    local zoneName = "Unknown"
    if type(_G.UI_GetPlayerZoneName) == "function" then
        local ok, z = pcall(_G.UI_GetPlayerZoneName, 0)
        if ok and z and z ~= "" then zoneName = z end
    elseif type(_G.UI_CurrentWorldName) == "function" then
        local ok, wname = pcall(_G.UI_CurrentWorldName)
        if ok and wname and wname ~= "" then zoneName = wname end
    end

    local rows = {}
    rows[#rows + 1] = { "Active Zone", tostring(zoneName), "cyan" }
    local heroName = (telem and telem.name and telem.name ~= "") and telem.name or State.avatarName
    rows[#rows + 1] = { "Hero / Avatar", string.format("%s (0x%X)", heroName, telem and telem.handle or 0), "white" }

    if telem then
        local modeText = "3D WORLD (Free Locomotion)"
        local modeColor = "green"
        if telem.coordType == 1 then
            modeText = string.format("2D SPLINE RAIL (Curve 0x%X)", telem.splineHandle)
            modeColor = "cyan"
        elseif telem.coordType == 2 then
            modeText = string.format("3D SPLINE RAIL (Curve 0x%X)", telem.splineHandle)
            modeColor = "royal"
        end
        rows[#rows + 1] = { "Locomotion Mode", modeText, modeColor }

        local camDist = math.sqrt(
            (telem.camX - telem.x) ^ 2 +
            (telem.camY - telem.y) ^ 2 +
            (telem.camZ - telem.z) ^ 2
        )
        local camColor = (telem.camMode ~= "Offline") and "cyan" or "muted"
        rows[#rows + 1] = { "Camera / Framing", string.format("%s (Dist: %.1fm | FOV: %.1f)", telem.camMode, camDist, telem.fov or 60.0), camColor }

        rows[#rows + 1] = { "Position (X, Y, Z)", string.format("%.1f,  %.1f,  %.1f", telem.x, telem.y, telem.z), "white" }

        if telem.rayHit then
            rows[#rows + 1] = {
                "Crosshair Raycast",
                string.format("%.2fm @ (%.1f, %.1f, %.1f) [S:%d]", telem.rayDist or 0, telem.rayX or 0, telem.rayY or 0, telem.rayZ or 0, telem.raySurf or 0),
                "green"
            }
        else
            rows[#rows + 1] = { "Crosshair Raycast", "No Hit (>150m)", "muted" }
        end

        local speed = math.sqrt(telem.vx * telem.vx + telem.vy * telem.vy + telem.vz * telem.vz)
        local tier = "IDLE"
        local speedColor = "red"
        if telem.submerged == 0 and telem.submersion < 0.5 then
            tier = "DOLPHIN JUMP / AIR"
            speedColor = "gold"
        elseif speed >= 11.0 then
            tier = "BURST KICK"
            speedColor = "cyan"
        elseif speed >= 5.5 then
            tier = "CRUISE SWIM"
            speedColor = "green"
        elseif speed >= 0.05 then
            tier = "SLOW STICK"
            speedColor = "green"
        end
        local speedStr = string.format("%.2f m/s [%s]", speed, tier)
        rows[#rows + 1] = { "Swim Speed & Tier", speedStr, speedColor }
        rows[#rows + 1] = { "Velocity Vector", string.format("Vx: %.1f  Vy: %.1f  Vz: %.1f", telem.vx, telem.vy, telem.vz), "muted" }

        local subState = (telem.submerged == 1) and "SUBMERGED" or "OUT OF WATER"
        local subText = string.format("%.0f%% (%s)", telem.submersion * 100, subState)
        local subColor = (telem.submerged == 1) and "cyan" or "gold"
        rows[#rows + 1] = { "Water Submersion", subText, subColor }

        if telem.waterSurfaceY < 9999.0 then
            local depth = telem.waterSurfaceY - telem.y
            rows[#rows + 1] = { "Water Surface Y", string.format("Y = %.2fm (Depth: %+.2fm)", telem.waterSurfaceY, depth), "cyan" }
        else
            rows[#rows + 1] = { "Water Surface Y", "Open Water Volume (No Ceiling)", "muted" }
        end

        local choText = string.format("Idle (%d in pool)", telem.choCount)
        local choColor = "muted"
        if telem.choPlaying == 1 and telem.choLoading == 1 then
            choText = string.format("PLAYING + LOADING (%d) -> F11", telem.choCount)
            choColor = "gold"
        elseif telem.choPlaying == 1 then
            choText = string.format("PLAYING CUTSCENE (%d) -> F11", telem.choCount)
            choColor = "gold"
        elseif telem.choLoading == 1 then
            choText = string.format("PRELOADING ASYNC (%d)", telem.choCount)
            choColor = "cyan"
        end
        rows[#rows + 1] = { "Choreographies", choText, choColor }
    else
        rows[#rows + 1] = { "Native Telemetry", "Waiting for physics thread...", "gold" }
    end

    local missText, missColor = getMissingTexturesInfo()
    rows[#rows + 1] = { "Missing Textures", missText, missColor }

    -- Diagnostic status for cinematics / controls
    local isLocked = false
    if type(_G.IsControllerLocked) == "function" then
        local ok, locked = pcall(_G.IsControllerLocked, 0)
        if ok and locked then isLocked = true end
    end

    local alertText = "PLAYER CONTROLS: ACTIVE (100%)"
    local alertColor = "green"
    if isLocked then
        alertText = "CONTROLS LOCKED (CUTSCENE) -> F11 SKIP"
        alertColor = "red"
    elseif telem and telem.playerControl == 0 then
        alertText = "AI CONTROL (RESTORING PLAYER CTRL...)"
        alertColor = "gold"
    end
    rows[#rows + 1] = { "Control Status", alertText, alertColor }

    local bodyHeight = #rows * ROW_HEIGHT + 36

    -- Header (Obsidian palette)
    Theme.rect(x, y, w, HEADER_HEIGHT, Theme.color("night", 250), 4)
    Theme.rect(x, y, w, HEADER_HEIGHT, Theme.color("panel", 200), 4, 1)
    Theme.rowText(x + PADDING, y, HEADER_HEIGHT, "DEV MODE - ENGINE & LOCOMOTION INSPECTOR", Theme.color("gold"), 13, ALIGN.LEFT, w, FONT.BODY)
    Theme.rect(x, y + HEADER_HEIGHT - 1, w, 1, Theme.color("gold"))

    -- Body
    local top = y + HEADER_HEIGHT
    Theme.rect(x, top, w, bodyHeight, Theme.color("night", 235), 4)
    Theme.rect(x, top, w, bodyHeight, Theme.color("panel", 160), 4, 1)

    for index, row in ipairs(rows) do
        drawRow(x, top + 4 + (index - 1) * ROW_HEIGHT, w, row[1], row[2], row[3], 145)
    end

    -- Footer shortcuts
    local fy = top + bodyHeight - 24
    Theme.rect(x, fy - 2, w, 1, Theme.color("muted", 60))
    Theme.rowText(x + PADDING, fy, 20, "F1: FreeCam | F2: God | F3: 1Hit | F8: Checkpoint | F6: HUD | F11: Skip", Theme.color("muted"), 11, ALIGN.CENTER, w - PADDING * 2)
end

function Overlay.render()
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or screenWidth <= 0 then screenWidth, screenHeight = FALLBACK_WIDTH, FALLBACK_HEIGHT end
    local factor = screenHeight / DESIGN_HEIGHT
    Theme.beginFrame(factor, 0, 0, 1)

    -- Render Dev Inspector on the left side
    renderDevInspector(factor)

    -- Render the Infinity Monitor on the right side
    local w = Config.UI.OVERLAY_WIDTH
    local margin = Config.UI.OVERLAY_MARGIN
    local onLeft = State.isMenuOpen and State.menuSide == "right"
    local x = onLeft and (margin + 490) or (screenWidth / factor - margin - w)
    local y = margin

    local renderFps = Crabe.GetRenderFps and Crabe.GetRenderFps() or 0
    if renderFps > 0 then
        State.fps = renderFps
        State.frameTime = 1 / renderFps
    end

    local health, healthColor = healthText()
    local candidates = {
        { "fps", "Performance", string.format("%.0f FPS  (%.1f ms)", State.fps, State.frameTime * 1000), fpsColor() },
        { "hero", "Hero", State.avatarName, "white" },
        { "health", "Health", health, healthColor },
        { "memory", "Lua memory", string.format("%.2f MB", collectgarbage("count") / 1024), "muted" },
    }
    if Speedrun.hasTimerReading() then
        candidates[#candidates + 1] = { "timer", "Timer", Speedrun.timerText(), Speedrun.isTimerRunning() and "gold" or "muted" }
    end
    local rows = {}
    for _, candidate in ipairs(candidates) do
        if not State.monitorHidden[candidate[1]] then rows[#rows + 1] = { candidate[2], candidate[3], candidate[4] } end
    end
    local active = badges()
    if State.monitorHidden.badges then active = {} end
    local bodyHeight = #rows * ROW_HEIGHT + 8 + (#active > 0 and BADGE_HEIGHT or 0)

    Theme.gradient(x, y, w, HEADER_HEIGHT, Theme.color("royal", 245), Theme.color("violet", 245), true)
    Theme.rowText(x + PADDING, y, HEADER_HEIGHT, "INFINITY MONITOR", Theme.color("white"), 14, ALIGN.LEFT, w, FONT.BODY)
    Theme.rowText(x, y, HEADER_HEIGHT, "\226\136\158", Theme.color("ice", 170), 20, ALIGN.RIGHT, w - PADDING)
    Theme.rect(x, y + HEADER_HEIGHT - 2, w, 2, Theme.color("gold"))

    local top = y + HEADER_HEIGHT
    Theme.rect(x, top, w, bodyHeight, Theme.color("panel", 215))
    for index, row in ipairs(rows) do
        drawRow(x, top + 4 + (index - 1) * ROW_HEIGHT, w, row[1], row[2], row[3], 110)
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
