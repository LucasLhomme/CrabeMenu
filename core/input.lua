local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")

local Input = {}

local VK = Config.VK
local REPEAT = Config.REPEAT
local TRIGGER_THRESHOLD = 128

local PAD = (Crabe.Input and Crabe.Input.PAD) or {
    DPAD_UP = 0x0001, DPAD_DOWN = 0x0002, DPAD_LEFT = 0x0004, DPAD_RIGHT = 0x0008,
    START = 0x0010, BACK = 0x0020, LB = 0x0100, RB = 0x0200, A = 0x1000, B = 0x2000, X = 0x4000, Y = 0x8000,
}

local NAVIGATION = {
    up = { keys = { VK.UP }, pad = { PAD.DPAD_UP }, stick = "up", repeats = true },
    down = { keys = { VK.DOWN }, pad = { PAD.DPAD_DOWN }, stick = "down", repeats = true },
    left = { keys = { VK.LEFT }, pad = { PAD.DPAD_LEFT }, stick = "left", repeats = true },
    right = { keys = { VK.RIGHT }, pad = { PAD.DPAD_RIGHT }, stick = "right", repeats = true },
    select = { keys = { VK.ENTER }, pad = { PAD.A } },
    back = { keys = { VK.BACKSPACE, VK.ESCAPE }, pad = { PAD.B } },
    pageUp = { keys = { VK.PAGE_UP }, trigger = "left", repeats = true },
    pageDown = { keys = { VK.PAGE_DOWN }, trigger = "right", repeats = true },
    first = { keys = { VK.HOME } },
    last = { keys = { VK.END } },
}

local TYPING = {
    confirm = { keys = { VK.ENTER }, pad = { PAD.A } },
    cancel = { keys = { VK.ESCAPE }, pad = { PAD.B } },
    erase = { keys = { VK.BACKSPACE, VK.DELETE }, pad = { PAD.X }, repeats = true },
}

local timers = {}
local edges = {}

local function isKeyDown(code)
    return Crabe._keyDown(code) == 1
end

local function readPad()
    if not (Crabe.Input and Crabe.Input.padState) then return nil end
    return Crabe.Input.padState(0)
end

local function padButton(pad, mask)
    return pad ~= nil and Crabe.Input.padHas(pad.buttons, mask)
end

local function stickHeld(pad, direction)
    if not pad then return false end
    local limit = REPEAT.STICK_THRESHOLD
    if direction == "up" then return pad.leftY > limit end
    if direction == "down" then return pad.leftY < -limit end
    if direction == "left" then return pad.leftX < -limit end
    return pad.leftX > limit
end

local function triggerHeld(pad, side)
    if not pad then return false end
    local value = (side == "left") and pad.leftTrigger or pad.rightTrigger
    return value > TRIGGER_THRESHOLD
end

local function heldBy(binding, pad)
    for _, code in ipairs(binding.keys or {}) do
        if isKeyDown(code) then return "keyboard" end
    end
    for _, mask in ipairs(binding.pad or {}) do
        if padButton(pad, mask) then return "pad" end
    end
    if binding.stick and stickHeld(pad, binding.stick) then return "pad" end
    if binding.trigger and triggerHeld(pad, binding.trigger) then return "pad" end
    return nil
end

local function step(name, binding, held, dt)
    local timer = timers[name]
    if not held then
        timers[name] = nil
        return false
    end
    if not timer then
        timers[name] = { heldFor = 0, nextAt = REPEAT.DELAY }
        return true
    end

    timer.heldFor = timer.heldFor + dt
    if not binding.repeats or timer.heldFor < timer.nextAt then return false end
    local interval = (timer.heldFor > REPEAT.FAST_AFTER) and REPEAT.FAST_INTERVAL or REPEAT.INTERVAL
    timer.nextAt = timer.nextAt + interval
    return true
end

local function pollBindings(bindings, dt, pad)
    local fired = {}
    for name, binding in pairs(bindings) do
        local device = heldBy(binding, pad)
        if device then State.lastDevice = device end
        if step(name, binding, device ~= nil, dt) then fired[name] = true end
    end
    return fired
end

local function rising(name, down)
    local pressed = down and not edges[name]
    edges[name] = down
    return pressed
end

--- Returns the menu actions fired this tick (up, down, left, right, select, back,
--- pageUp, pageDown, first, last), with key repeat for the directional ones.
function Input.navigation(dt)
    return pollBindings(NAVIGATION, dt, readPad())
end

--- Returns the text-entry actions fired this tick: confirm, cancel and erase.
function Input.typing(dt)
    return pollBindings(TYPING, dt, readPad())
end

--- Swallows every key and button held right now until it is released, so the
--- Enter that closes a prompt does not also select the row behind it.
function Input.swallowHeld()
    local pad = readPad()
    for _, bindings in ipairs({ NAVIGATION, TYPING }) do
        for name, binding in pairs(bindings) do
            if heldBy(binding, pad) then timers[name] = { heldFor = 0, nextAt = math.huge } end
        end
    end
end

--- Reports whether F5, or RB + D-pad left on the controller, was just pressed.
function Input.menuToggled()
    local pad = readPad()
    local combo = padButton(pad, PAD.RB) and padButton(pad, PAD.DPAD_LEFT)
    local keyboard = rising("menu", isKeyDown(Config.KEYS.MENU_TOGGLE))
    local controller = rising("menuPad", combo)
    if controller then State.lastDevice = "pad" end
    return keyboard or controller
end

--- Reports whether F6 was just pressed.
function Input.overlayToggled()
    return rising("overlay", isKeyDown(Config.KEYS.OVERLAY_TOGGLE))
end

local function characterFor(code, shift)
    if code >= 0x41 and code <= 0x5A then
        local letter = string.char(code)
        return shift and letter or letter:lower()
    end
    if code >= 0x30 and code <= 0x39 then return string.char(code) end
    if code >= VK.NUMPAD_0 and code <= VK.NUMPAD_0 + 9 then return string.char(code - VK.NUMPAD_0 + 0x30) end
    if code == VK.SPACE then return " " end
    if code == VK.DECIMAL or code == VK.OEM_PERIOD then return "." end
    if code == VK.OEM_COMMA then return "," end
    if code == VK.OEM_MINUS then return shift and "_" or "-" end
    return nil
end

local TEXT_CODES = {}
for code = 0x30, 0x39 do TEXT_CODES[#TEXT_CODES + 1] = code end
for code = 0x41, 0x5A do TEXT_CODES[#TEXT_CODES + 1] = code end
for code = VK.NUMPAD_0, VK.NUMPAD_0 + 9 do TEXT_CODES[#TEXT_CODES + 1] = code end
for _, code in ipairs({ VK.SPACE, VK.DECIMAL, VK.OEM_PERIOD, VK.OEM_COMMA, VK.OEM_MINUS, VK.DELETE }) do
    TEXT_CODES[#TEXT_CODES + 1] = code
end

--- Every key a prompt reads, for keeping them away from the game while typing.
Input.TEXT_KEYS = TEXT_CODES

--- Returns the characters whose key went down this tick, in key-code order.
function Input.typedCharacters()
    local shift = isKeyDown(VK.SHIFT)
    local typed = {}
    for _, code in ipairs(TEXT_CODES) do
        if rising("text" .. code, isKeyDown(code)) then
            local character = characterFor(code, shift)
            if character then typed[#typed + 1] = character end
        end
    end
    return table.concat(typed)
end

--- Marks every text key as already held, so the key that opened a prompt is not typed.
function Input.primeTyping()
    for _, code in ipairs(TEXT_CODES) do edges["text" .. code] = isKeyDown(code) end
end

return Input
