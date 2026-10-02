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

-- The free camera holds the game camera; it is handed back before the world goes away.
local function releaseFreeCam()
    if not Loader.exists("modules.freecam") then return end
    local FreeCam = Loader.load("modules.freecam")
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

-- A world the game refuses (UI_CanTransitionToLevel) is only forced on a
-- second press within this window: a forced transition can leave the session
-- on a loading screen with no way back, so it is never a single press.
local FORCE_WINDOW = 5
local forceArmed = { name = nil, at = -FORCE_WINDOW }

--- Loads any world of the zone list by name. One the game accepts loads at
--- once; one it refuses asks for a second press, which forces it.
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
    if not Native.run("Game.LoadLevel", Game.LoadLevel, name, not allowed) then return false end
    State.setStatus((allowed and "Loading " or "Forcing ") .. name .. "...", allowed and "success" or "warning")
    return true
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
