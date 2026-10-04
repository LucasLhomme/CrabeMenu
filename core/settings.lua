local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local Settings = {}

local function storage()
    return Crabe.Storage and Crabe.Storage.save and Crabe.Storage.load and Crabe.Storage or nil
end

--- Restores the menu side, size, overlay and playset bypass choices saved by a previous session.
function Settings.load()
    local store = storage()
    if not store then return end

    local saved = Native.poll(store.load, Config.SETTINGS_FILE)
    if type(saved) ~= "table" then return end
    if saved.menuSide == "left" or saved.menuSide == "right" then State.menuSide = saved.menuSide end
    if Config.SCALES[tonumber(saved.scaleIndex) or 0] then State.scaleIndex = tonumber(saved.scaleIndex) end
    if saved.overlay == true then State.isOverlayOpen = true end
    if type(saved.playsetBypass) == "boolean" then State.playsetBypass = saved.playsetBypass end
end

--- Writes the current menu side, size, overlay and playset bypass choices to disk.
function Settings.save()
    local store = storage()
    if not store then return end

    Native.poll(store.save, Config.SETTINGS_FILE, {
        menuSide = State.menuSide,
        scaleIndex = State.scaleIndex,
        overlay = State.isOverlayOpen,
        playsetBypass = State.playsetBypass,
    })
end

return Settings
