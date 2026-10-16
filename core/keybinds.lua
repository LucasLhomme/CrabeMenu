local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local Keybinds = {}

local FIRST_KEYBOARD_CODE = 0x08
local LAST_KEYBOARD_CODE = 0xFE
local CANCEL_CODE = 0x1B

local NAMES = {
    BACKSPACE = 0x08, TAB = 0x09, ENTER = 0x0D, SPACE = 0x20, ESCAPE = 0x1B,
    PAGEUP = 0x21, PAGEDOWN = 0x22, END = 0x23, HOME = 0x24,
    LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28,
    INSERT = 0x2D, DELETE = 0x2E, MINUS = 0xBD, COMMA = 0xBC, PERIOD = 0xBE,
}
for number = 0, 9 do NAMES["NUMPAD" .. number] = 0x60 + number end
for number = 1, 12 do NAMES["F" .. number] = 0x6F + number end

local NAME_OF = {}
for name, code in pairs(NAMES) do NAME_OF[code] = name end

local PRETTY = {
    BACKSPACE = "Backspace", ENTER = "Enter", ESCAPE = "Esc", PAGEUP = "Page Up", PAGEDOWN = "Page Down",
    LEFT = "Left", RIGHT = "Right", UP = "Up", DOWN = "Down", SPACE = "Space", TAB = "Tab",
    HOME = "Home", END = "End", INSERT = "Insert", DELETE = "Delete",
}

--- Every rebindable action in menu order: id, label, group and default key names.
Keybinds.ACTIONS = {
    { id = "menuToggle", label = "Open / close the menu", group = "Menu", keys = { "F5" } },
    { id = "overlayToggle", label = "Runtime overlay", group = "Menu", keys = { "F6" } },
    { id = "up", label = "Move up", group = "Navigation", keys = { "UP" } },
    { id = "down", label = "Move down", group = "Navigation", keys = { "DOWN" } },
    { id = "left", label = "Change left", group = "Navigation", keys = { "LEFT" } },
    { id = "right", label = "Change right", group = "Navigation", keys = { "RIGHT" } },
    { id = "select", label = "Select", group = "Navigation", keys = { "ENTER" } },
    { id = "back", label = "Back", group = "Navigation", keys = { "BACKSPACE", "ESCAPE" } },
    { id = "pageUp", label = "Page up", group = "Navigation", keys = { "PAGEUP" } },
    { id = "pageDown", label = "Page down", group = "Navigation", keys = { "PAGEDOWN" } },
    { id = "first", label = "First row", group = "Navigation", keys = { "HOME" } },
    { id = "last", label = "Last row", group = "Navigation", keys = { "END" } },
    { id = "positionSave", label = "Save position", group = "Speedrun", keys = { "F7" } },
    { id = "positionLoad", label = "Teleport to saved position", group = "Speedrun", keys = { "F8" } },
    { id = "timerToggle", label = "Start / pause timer", group = "Speedrun", keys = { "F9" } },
    { id = "reloadWorld", label = "Reload this world", group = "Speedrun", keys = { "F3" } },
    { id = "hudToggle", label = "Speedrun HUD", group = "Speedrun", keys = { "F11" } },
}

local bindings = {}
local byId = {}
local capturing = nil
local held = {}

for _, action in ipairs(Keybinds.ACTIONS) do byId[action.id] = action end

local function parseKey(text)
    if type(text) ~= "string" then return nil end
    local upper = text:upper():gsub("%s", "")
    if NAMES[upper] then return NAMES[upper] end
    if #upper == 1 then
        local code = upper:byte()
        if (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) then return code end
    end
    local hex = upper:match("^0X(%x+)$")
    local code = hex and tonumber(hex, 16)
    if code and code >= FIRST_KEYBOARD_CODE and code <= LAST_KEYBOARD_CODE then return code end
    return nil
end

local function nameOf(code)
    if NAME_OF[code] then return NAME_OF[code] end
    if (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x5A) then return string.char(code) end
    return string.format("0x%02X", code)
end

local function prettyName(code)
    local name = nameOf(code)
    return PRETTY[name] or name
end

local function defaultCodes(action)
    local codes = {}
    for _, name in ipairs(action.keys) do codes[#codes + 1] = parseKey(name) end
    return codes
end

local function parseList(value)
    local list = type(value) == "table" and value or { value }
    local codes = {}
    for _, entry in ipairs(list) do
        local code = parseKey(entry)
        if code then codes[#codes + 1] = code end
    end
    return codes
end

local function toNames(codes)
    local names = {}
    for _, code in ipairs(codes) do names[#names + 1] = nameOf(code) end
    return names
end

local function storage()
    return Crabe.Storage and Crabe.Storage.save and Crabe.Storage.load and Crabe.Storage or nil
end

local function resetAllToDefaults()
    for _, action in ipairs(Keybinds.ACTIONS) do bindings[action.id] = defaultCodes(action) end
end

--- Writes every binding to the keybinds file, one list of key names per action.
function Keybinds.save()
    local store = storage()
    if not store then return end

    local data = {}
    for _, action in ipairs(Keybinds.ACTIONS) do data[action.id] = toNames(bindings[action.id]) end
    Native.poll(store.save, Config.KEYBINDS_FILE, data)
end

--- Reads the keybinds file; a missing file is created from the defaults so it can be edited by hand.
--- A key name the file gets wrong falls back to that action's default.
function Keybinds.load()
    resetAllToDefaults()

    local store = storage()
    local saved = store and Native.poll(store.load, Config.KEYBINDS_FILE)
    if type(saved) ~= "table" then
        Keybinds.save()
        return
    end

    for _, action in ipairs(Keybinds.ACTIONS) do
        local codes = saved[action.id] ~= nil and parseList(saved[action.id]) or {}
        if #codes > 0 then bindings[action.id] = codes end
    end
end

--- Returns the key codes bound to an action.
function Keybinds.codes(id)
    return bindings[id] or {}
end

--- Returns every key code bound to any navigation action, for keeping them away from the game.
function Keybinds.navigationCodes()
    local codes = {}
    for _, action in ipairs(Keybinds.ACTIONS) do
        if action.group == "Navigation" then
            for _, code in ipairs(bindings[action.id]) do codes[#codes + 1] = code end
        end
    end
    return codes
end

--- Returns the keys of an action as readable text, "Backspace / Esc" for two keys.
function Keybinds.label(id)
    local names = {}
    for _, code in ipairs(bindings[id] or {}) do names[#names + 1] = prettyName(code) end
    return table.concat(names, " / ")
end

--- Puts one action back on its default keys.
function Keybinds.reset(id)
    bindings[id] = defaultCodes(byId[id])
    Keybinds.save()
    if State.applyCapture then State.applyCapture() end
end

--- Puts every action back on its default keys.
function Keybinds.resetAll()
    resetAllToDefaults()
    Keybinds.save()
    if State.applyCapture then State.applyCapture() end
    State.setStatus("Keybinds back to the defaults", "success")
end

local function holdCurrentKeys()
    held = {}
    for code = FIRST_KEYBOARD_CODE, LAST_KEYBOARD_CODE do
        if Crabe._keyDown(code) == 1 then held[code] = true end
    end
end

--- Starts waiting for the next key press to bind to an action; Esc cancels.
function Keybinds.beginCapture(id)
    capturing = id
    holdCurrentKeys()
    State.setStatus("Press the new key for " .. byId[id].label .. " (Esc cancels)", "info")
end

--- Reports whether a key is being waited for.
function Keybinds.isCapturing()
    return capturing ~= nil
end

local function isNavigation(action)
    return action.group == "Navigation"
end

local function otherUser(id, code)
    for _, action in ipairs(Keybinds.ACTIONS) do
        if action.id ~= id and isNavigation(action) == isNavigation(byId[id]) then
            for _, bound in ipairs(bindings[action.id]) do
                if bound == code then return action end
            end
        end
    end
    return nil
end

--- Binds the first key pressed since the capture started, or cancels on Esc.
function Keybinds.updateCapture()
    if not capturing then return end
    State.setStatus("Press the new key for " .. byId[capturing].label .. " (Esc cancels)", "info")

    for code = FIRST_KEYBOARD_CODE, LAST_KEYBOARD_CODE do
        local down = Crabe._keyDown(code) == 1
        if down and not held[code] then
            local id = capturing
            capturing = nil
            if code == CANCEL_CODE then
                State.setStatus("Keybind unchanged", "info")
                return
            end

            bindings[id] = { code }
            Keybinds.save()
            if State.applyCapture then State.applyCapture() end
            local clash = otherUser(id, code)
            State.setStatus(byId[id].label .. ": " .. prettyName(code) .. (clash and (" (also used by " .. clash.label .. ")") or ""),
                clash and "warning" or "success")
            return
        end
        held[code] = down or nil
    end
end

State.reservedKeys = function()
    local keys = { 0x2D, 0x73 }
    for _, id in ipairs({ "menuToggle", "overlayToggle" }) do
        for _, code in ipairs(bindings[id] or {}) do keys[#keys + 1] = code end
    end
    return keys
end

State.navigationKeys = Keybinds.navigationCodes

return Keybinds
