local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local FreeCam = {}

--- Reports whether the engine free camera is running.
function FreeCam.isActive()
    return Crabe.Camera.IsFreeCamActive() == true
end

--- Starts or stops the engine free camera.
function FreeCam.toggle()
    if FreeCam.isActive() then
        if not Native.run("Camera.StopFreeCam", Crabe.Camera.StopFreeCam) then return false end
        State.setStatus("Free camera disabled", "info")
        return true
    end

    local ok, started = Native.run("Camera.StartFreeCam", Crabe.Camera.StartFreeCam)
    if not ok then return false end
    if not started then
        State.setStatus("Free camera unavailable here, load a world first", "warning")
        return false
    end
    State.setStatus("Free camera enabled (left stick: fly, right stick: look)", "success")
    return true
end

--- Moves the avatar to where the free camera currently is.
function FreeCam.teleportPlayerToCamera()
    if not FreeCam.isActive() then
        State.setStatus("Start the free camera and fly to the destination first", "warning")
        return false
    end

    local ok, placed, reason = Native.run("Camera.MovePlayerToCamera", Crabe.Camera.MovePlayerToCamera)
    if not ok then return false end
    if not placed then return Native.fail("Teleport failed: " .. tostring(reason)) end

    State.setStatus("Avatar teleported to the camera", "success")
    return true
end

return FreeCam
