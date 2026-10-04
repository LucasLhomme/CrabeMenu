local Loader = ...
local State = Loader.load("core.state")

local Native = {}

local function report(label, ok, ...)
    if ok then return true, ... end
    Native.fail(label .. ": " .. tostring((...)))
    return false, ...
end

local function valueOnSuccess(ok, ...)
    if ok then return ... end
    return nil
end

--- Shows an error in the footer, logs it to loader.log and returns false.
function Native.fail(message)
    State.setStatus(message, "error")
    Crabe.write("[CrabeMenu] " .. message)
    return false
end

--- Calls a game or loader function; a raised error is reported instead of propagated.
--- Returns true plus the call's results, or false plus the error.
function Native.run(label, fn, ...)
    return report(label, pcall(fn, ...))
end

--- Calls a function whose failure is expected in some game states and stays silent.
--- Returns the call's results, or nil when it raised.
function Native.poll(fn, ...)
    return valueOnSuccess(pcall(fn, ...))
end

return Native
