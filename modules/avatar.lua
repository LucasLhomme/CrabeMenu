local Loader = ...
local Native = Loader.load("core.native")

local Avatar = {}

--- Returns the host avatar's actor handle, or nil on the main menu or while none is loaded.
function Avatar.handle()
    local world = Native.poll(Game.CurrentWorld)
    if type(world) ~= "string" or world:lower() == "frontend" then return nil end
    return Native.poll(Game.GetAvatarHandle)
end

return Avatar
