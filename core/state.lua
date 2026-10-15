local Loader = ...
local Config = Loader.load("core.config")

local State = {
    isMenuOpen = false,
    isOverlayOpen = false,
    isTyping = false,

    statusMessage = "",
    statusType = "info",
    statusTime = -1000,
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
    -- playsetBypass stays nil until the player picks; modules.playset_bypass reads nil as on.

    menuSide = "left",
    scaleIndex = 2,
    lastDevice = "keyboard",
    lockControls = true,
}

local typingKeys = {}

local function applyCapture()
    if not State.isMenuOpen then
        Crabe.Input.captureKeys(nil)
        if Crabe.Input.capturePad then Crabe.Input.capturePad(false) end
        if Crabe.Input.captureDirectInput then Crabe.Input.captureDirectInput(false) end
        if State._controlsLockedByMenu and Crabe.Input.clearRemap then
            State._controlsLockedByMenu = false
            Crabe.Input.clearRemap()
        end
        return
    end

    local keys = {}
    if State.lockControls then
        if Crabe.Input.captureDirectInput then Crabe.Input.captureDirectInput(true) end
        if Crabe.Input.capturePad then Crabe.Input.capturePad(true) end
        for code = 1, 255 do
            if code ~= Config.VK.F5 and code ~= Config.VK.F6 and code ~= 0x2D and code ~= 0x73 then
                keys[#keys + 1] = code
            end
        end
        if Crabe.Input.remapMouseButton then
            State._controlsLockedByMenu = true
            for btn = 0, 7 do
                Crabe.Input.remapMouseButton(btn, -1)
            end
        end
    else
        if Crabe.Input.captureDirectInput then Crabe.Input.captureDirectInput(false) end
        if Crabe.Input.capturePad then Crabe.Input.capturePad(false) end
        for _, code in ipairs(Config.NAV_KEYS) do keys[#keys + 1] = code end
        if State.isTyping then
            for _, code in ipairs(typingKeys) do keys[#keys + 1] = code end
        end
        if State._controlsLockedByMenu and Crabe.Input.clearRemap then
            State._controlsLockedByMenu = false
            Crabe.Input.clearRemap()
        end
    end
    Crabe.Input.captureKeys(keys)
end

State.applyCapture = applyCapture

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

--- Opens or closes the menu; while open the game no longer sees the menu keys or the pad.
function State.setMenuOpen(open)
    State.isMenuOpen = (open == true)
    if not State.isMenuOpen then State.isTyping = false end
    applyCapture()
end

--- Starts or stops text entry; `keys` are kept away from the game while it lasts.
function State.setTyping(typing, keys)
    State.isTyping = (typing == true)
    typingKeys = keys or {}
    applyCapture()
end

--- Toggles the runtime overlay.
function State.toggleOverlay()
    State.isOverlayOpen = not State.isOverlayOpen
    State.setStatus("Runtime overlay " .. (State.isOverlayOpen and "enabled" or "disabled"), "info")
end

--- Returns the menu scale factor picked in the settings.
function State.menuScale()
    local entry = Config.SCALES[State.scaleIndex] or Config.SCALES[2]
    return entry.value
end

return State
