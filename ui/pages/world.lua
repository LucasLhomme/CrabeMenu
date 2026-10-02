local Loader = ...
local Items = Loader.load("ui.items")
local FreeCam = Loader.load("modules.freecam")

local function setFreeCam(on)
    if on ~= FreeCam.isActive() then FreeCam.toggle() end
end

local ITEMS = {
    Items.toggle("Free camera", FreeCam.isActive, setFreeCam, "Fly the camera anywhere; close the menu to steer it"),
    Items.action("Teleport hero to camera", FreeCam.teleportPlayerToCamera, "Drops your hero where the free camera is"),
}

return {
    title = "Camera",
    items = function() return ITEMS end,
}
