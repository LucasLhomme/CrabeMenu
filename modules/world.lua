local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local FreeCam = Loader.load("modules.freecam")
local Avatar = Loader.load("modules.avatar")

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

-- Each of these starts a level transition, and a held key or a double press
-- can reach them twice: a second request inside this window is dropped.
local LEAVE_COOLDOWN = 5
local lastLeave = -LEAVE_COOLDOWN

local function leaveAllowed()
    if State.gameClock - lastLeave < LEAVE_COOLDOWN then
        State.setStatus("Already leaving, wait for the transition", "warning")
        return false
    end
    lastLeave = State.gameClock
    return true
end

local function releaseFreeCam()
    if FreeCam.isActive() then FreeCam.toggle() end
end

local function inFrontEnd()
    local world = Native.poll(Game.CurrentWorld)
    return type(world) == "string" and world:lower() == "frontend"
end

--- Leaves the current world for the main menu and its world select: the pause
--- menu's own Quit (pausemenu.lua PauseExit) without its popup. The game
--- autosaves first. Returns true when the request was sent.
function WorldModule.goToMainMenu()
    if inFrontEnd() then
        State.setStatus("Already in the main menu", "info")
        return false
    end
    if not leaveAllowed() then return false end
    releaseFreeCam()
    if not Native.run("Game.QuitToMainMenu", Game.QuitToMainMenu) then return false end
    State.setStatus("Going to the main menu...", "success")
    return true
end

--- Sends the player back to the hub world. Returns true when the request was sent.
function WorldModule.returnToHub()
    if inFrontEnd() then
        State.setStatus("No hub from the main menu: load a world first", "warning")
        return false
    end
    if not leaveAllowed() then return false end
    releaseFreeCam()
    if not Native.run("Game.ReturnToHub", Game.ReturnToHub) then return false end
    State.setStatus("Returning to the hub...", "success")
    return true
end

--- Replaces the sky and its lighting with a realm of realms/realmlist.lua. The engine keeps it
--- until the world is reloaded: nothing hands back the world's own sky. Returns true when loaded.
function WorldModule.loadSky(realm)
    if inFrontEnd() then
        State.setStatus("No sky in the main menu: load a world first", "warning")
        return false
    end

    local ok, loaded = Native.run("Game.LoadSkyDome", Game.LoadSkyDome, realm)
    if not ok then return false end
    if loaded ~= true then
        State.setStatus("The engine refused the sky " .. realm, "warning")
        return false
    end
    State.setStatus("Sky: " .. realm .. " (stays until the world reloads)", "success")
    return true
end

-- A world the game refuses (UI_CanTransitionToLevel) is only forced on a
-- second press within this window: a forced transition can leave the session
-- on a loading screen with no way back, so it is never a single press.
local FORCE_WINDOW = 5
local forceArmed = { name = nil, at = -FORCE_WINDOW }

local PENDING_LIFETIME = 120
local SETTLE_TIME = 4
local PENDING_INTERVAL = 0.5

local pending = nil
local pendingCheckedAt = 0

local function currentPlayset()
    local zone = Native.poll(Game.CurrentZone)
    if type(zone) ~= "string" or zone == "" then return nil end
    return Native.poll(Game.ZoneString, "PlaysetProperties", zone)
end

local function insidePlayset(playset)
    return not inFrontEnd() and currentPlayset() == playset
end

--- Returns the Play Set whose saved game the zone belongs to, or nil when the zone
--- is not in a story Play Set or that Play Set has no save to resume.
local function resumablePlayset(zone)
    if type(Game.ContinuePlayset) ~= "function" or type(Game.CanContinuePlayset) ~= "function" then return nil end

    local playset = Native.poll(Game.ZoneString, "PlaysetProperties", zone)
    if type(playset) ~= "string" or playset == "" or playset == "ToyBox" then return nil end
    if Native.poll(Game.CanContinuePlayset, playset) ~= true then return nil end
    return playset
end

--- Loads any world of the zone list by name. One the game accepts loads at
--- once; one it refuses asks for a second press, which forces it. Coming from outside its Play Set,
--- a zone of a Play Set with a saved game first resumes that save, then moves to the zone.
--- Returns true when the load was requested.
function WorldModule.travelTo(name)
    local allowed = Native.poll(Game.CanLoadLevel, name) == true
    local confirmed = forceArmed.name == name and State.gameClock - forceArmed.at < FORCE_WINDOW
    if not allowed and not confirmed then
        forceArmed.name, forceArmed.at = name, State.gameClock
        State.setStatus("The game refuses " .. name .. ": select it again within 5 s to force it (may get stuck loading)",
            "warning")
        return false
    end

    if not leaveAllowed() then return false end
    forceArmed.name = nil
    releaseFreeCam()

    local playset = allowed and resumablePlayset(name)
    if playset and not insidePlayset(playset) then
        local saveZone = Native.poll(Game.ZoneString, "SaveZoneOverride", name)
        if type(saveZone) ~= "string" or saveZone == "" then saveZone = name end
        if not Native.run("Game.ContinuePlayset", Game.ContinuePlayset, playset, saveZone) then return false end

        pending = { zone = name, playset = playset, since = State.gameClock }
        State.setStatus("Resuming your " .. playset .. " save, then going to " .. name .. "...", "success")
        return true
    end

    if not Native.run("Game.LoadLevel", Game.LoadLevel, name, not allowed) then return false end
    State.setStatus((allowed and "Loading " or "Forcing ") .. name .. "...", allowed and "success" or "warning")
    return true
end

--- Finishes a travel that began by resuming a Play Set save: once the hero is standing in that
--- Play Set, moves to the zone that was asked for.
function WorldModule.onTick()
    if not pending then return end
    if State.gameClock - pending.since > PENDING_LIFETIME then
        pending = nil
        return
    end
    if State.gameClock - pendingCheckedAt < PENDING_INTERVAL then return end
    pendingCheckedAt = State.gameClock

    if not insidePlayset(pending.playset) or not Avatar.handle() then
        pending.settledAt = nil
        return
    end
    pending.settledAt = pending.settledAt or State.gameClock
    if State.gameClock - pending.settledAt < SETTLE_TIME then return end

    local target = pending.zone
    pending = nil
    if Native.poll(Game.CurrentZone) == target then return end

    lastLeave = State.gameClock
    if Native.run("Game.LoadLevel", Game.LoadLevel, target, false) then
        State.setStatus("Loading " .. target .. "...", "success")
    end
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

return WorldModule
