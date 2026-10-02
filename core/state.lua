local Loader = ...
local Config = Loader.load("core.config")

local State = {
    isMenuOpen = false,
    isOverlayOpen = false,

    statusMessage = "",
    statusType = "info",
    statusTime = 0,
    gameClock = 0,

    frameTime = 0.016,
    fps = 0,

    avatarName = "Avatar",
    avatarSku = 0,
    playerHealth = { current = nil, max = nil },

    applyRoute = "loadout",
    spawnCount = 1,
    godLocked = false,
    editorUnlocked = false,
}

--- Sets the footer message; type is "info", "success", "warning" or "error".
function State.setStatus(message, messageType)
    State.statusMessage = tostring(message or "")
    State.statusType = messageType or "info"
    State.statusTime = State.gameClock
end

--- Returns the footer message and its type while it is recent, otherwise nil.
function State.currentStatus()
    if State.statusMessage == "" then return nil end
    if State.gameClock - State.statusTime > Config.UI.STATUS_LIFETIME then return nil end
    return State.statusMessage, State.statusType
end

--- Opens or closes the menu and captures the navigation keys while it is open.
function State.setMenuOpen(open)
    State.isMenuOpen = (open == true)
    Crabe.Input.captureKeys(State.isMenuOpen and Config.NAV_KEYS or nil)
end

--- Toggles the runtime overlay.
function State.toggleOverlay()
    State.isOverlayOpen = not State.isOverlayOpen
    State.setStatus("Runtime overlay " .. (State.isOverlayOpen and "enabled" or "disabled"), "info")
end

return State
