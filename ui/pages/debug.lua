local Loader = ...
local Items = Loader.load("ui.items")
local State = Loader.load("core.state")
local FreeCam = Loader.load("modules.freecam")
local Cheats = Loader.load("modules.cheats")
local WorldModule = Loader.load("modules.world")

local function skipCinematic()
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("update_106.skip_cinematic", "1")
        Crabe.Plugins.set("dev_toolkit.skip_cinematic", "1")
    end
    if type(_G.ChoreographyKillAll) == "function" then
        pcall(_G.ChoreographyKillAll)
    end
    if type(_G.Update106_SkipCinematic) == "function" then
        pcall(_G.Update106_SkipCinematic)
    end
    if type(_G.System_UnlockAllControllers) == "function" then
        pcall(_G.System_UnlockAllControllers)
    end
    State.setStatus("Cinematic skipped & controls unlocked (F11)!", "info")
    return "Cinematic skipped!"
end

local function setFreeCam(on)
    if on ~= FreeCam.isActive() then FreeCam.toggle() end
end

local function passCheckpoint()
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("dev_toolkit.checkpoint", "1")
    end
    if Game and Game.GetAvatarHandle then
        local h = Game.GetAvatarHandle(0)
        if h and h ~= 0 and Game.PlaceActor then
            if Game.ActorKill then
                pcall(Game.ActorKill, h, 0, 0)
            end
        end
    end
    State.setStatus("Checkpoint passed (F5)!", "info")
end

local function unlockAll()
    if Cheats and Cheats.unlockEditorEverywhere then
        Cheats.unlockEditorEverywhere()
    end
    if Crabe and Crabe.Plugins and Crabe.Plugins.set then
        Crabe.Plugins.set("dev_toolkit.unlock", "1")
    end
    State.setStatus("All toys & editor unlocked!", "success")
end

local function travelTo(zone)
    return function()
        if WorldModule and WorldModule.travelTo then
            WorldModule.travelTo(zone)
        end
    end
end

local function getTelemetryInfo()
    if Crabe and Crabe.Plugins and Crabe.Plugins.get then
        local raw = Crabe.Plugins.get("dev_toolkit.telemetry")
        if raw and raw ~= "" and raw:match('"valid"%s*:%s*true') then
            local name = raw:match('"name"%s*:%s*"([^"]*)"') or "Actor"
            local x = tonumber(raw:match('"x"%s*:%s*([%-0-9%.]+)')) or 0
            local y = tonumber(raw:match('"y"%s*:%s*([%-0-9%.]+)')) or 0
            local z = tonumber(raw:match('"z"%s*:%s*([%-0-9%.]+)')) or 0
            local spd = tonumber(raw:match('"speed"%s*:%s*([%-0-9%.]+)')) or 0
            local fov = tonumber(raw:match('"fov"%s*:%s*([%-0-9%.]+)')) or 60
            return string.format("%s (%.1f, %.1f, %.1f) | %.1fm/s | FOV %.0f", name ~= "" and name or "Avatar", x, y, z, spd, fov)
        end
    end

    if Game and Game.GetAvatarHandle and Game.ActorPosition then
        local h = Game.GetAvatarHandle(0)
        if h and h ~= 0 then
            local x, y, z = Game.ActorPosition(h)
            if x then
                return string.format("X: %.1f  Y: %.1f  Z: %.1f", x, y, z)
            end
        end
    end
    return "Avatar not detected"
end

local function logCollisionDiagnostic()
    if not (Crabe and Crabe.Plugins and Crabe.Plugins.get) then
        State.setStatus("Crabe.Plugins API unavailable", "warning")
        return
    end
    local raw = Crabe.Plugins.get("dev_toolkit.telemetry")
    if not raw or raw == "" then
        State.setStatus("Waiting for live telemetry from DevToolkitNative", "warning")
        return
    end
    local dbg = Crabe.Plugins.get("dev_toolkit.debug_3d") or ""
    local _, radCount = dbg:gsub("RAD,", "")
    local _, splCount = dbg:gsub("SPL,", "")
    local _, trgCount = dbg:gsub("TRG,", "")
    local rayDist = tonumber(raw:match('"rayDist"%s*:%s*([%-0-9%.]+)')) or 0
    local rayHit = raw:match('"rayHit"%s*:%s*true') ~= nil
    local msg = string.format("[3D Diag] Ray: %s (%.2fm) | RAD: %d | SPL: %d | TRG: %d",
                              rayHit and "HIT" or "MISS", rayDist, radCount, splCount, trgCount)
    if Crabe.Log then pcall(Crabe.Log, msg) end
    State.setStatus(msg, "info")
end

local ITEMS = {
    Items.section("Engine & Display Inspector"),
    Items.toggle("On-Screen Dev Inspector (F6)", function() return State.isOverlayOpen end, function(v) State.isOverlayOpen = v end, "Show live telemetry, velocity, submersion and diagnostic HUD"),

    Items.section("3D World Debug Visualizers"),
    Items.toggle("3D Collision Wireframe (Octane)", function() return State.show3DCollisions end, function(v) State.show3DCollisions = v end, "Draw real Octane AABB, capsule, ground/ceiling/water rays, radial wall scan & 5x5 terrain grid"),
    Items.toggle("3D Navigation Splines & Rails", function() return State.show3DSplines end, function(v) State.show3DSplines = v end, "Draw live CurveBSpline rails, nearest points and tangents from CurveHandleManager"),
    Items.toggle("3D Trigger & Checkpoint Boxes", function() return State.show3DTriggers end, function(v) State.show3DTriggers = v end, "Draw real trigger volume collision hits and normals"),
    Items.toggle("3D Animation Rig & Locators", function() return State.show3DAnimRig end, function(v) State.show3DAnimRig = v end, "Draw live 3D skeleton joints and locators for selected actor or avatar"),
    Items.action("Run 3D Collision & Spline Diagnostic", logCollisionDiagnostic, "Inspect live raycast, radial collision, spline and trigger counts"),

    Items.section("Cheats & Gameplay (Avalanche DevTools)"),
    Items.toggle("God Mode / Invincibility (F2)", Cheats.isGodMode, Cheats.setGodMode, "Immunity to all incoming damage"),
    Items.toggle("One-Hit Kills (F3)", Cheats.isOneShotKill, Cheats.setOneShotKill, "Defeat targets in a single hit"),
    Items.action("Pass Checkpoint (F8)", passCheckpoint, "Advance to next checkpoint or reload stage phase"),
    Items.action("Unlock Player Controls", function()
        if type(_G.System_UnlockAllControllers) == "function" then
            pcall(_G.System_UnlockAllControllers)
        end
        State.setStatus("Controllers unlocked!", "success")
    end, "Force engine to unlock all controller and keyboard inputs"),
    Items.action("Unlock All (Toys & Editor)", unlockAll, "Unlock all toys and enable Toy Box editor everywhere"),

    Items.section("Cinematics & Transitions"),
    Items.action("Skip Cinematic (F11)", skipCinematic, "Instantly abort active cutscene or choreography"),

    Items.section("Fast Travel"),
    Items.action("Go to Reef (DOR_Reef)", travelTo("DOR_Reef"), "Teleport to 3D open ocean area"),
    Items.action("Go to Intro (DOR_Intro)", travelTo("DOR_Intro"), "Teleport to 2D pipe prologue area"),

    Items.section("Camera & Position"),
    Items.toggle("Free Camera (F1)", FreeCam.isActive, setFreeCam, "Detach camera to fly freely across the level"),
    Items.action("Teleport Hero to Camera", FreeCam.teleportPlayerToCamera, "Place player avatar at current camera position"),
    Items.info("Player Position", getTelemetryInfo, "Live world coordinates of the avatar"),
}

return {
    title = "Debug & Dev Tools",
    items = function() return ITEMS end,
}
