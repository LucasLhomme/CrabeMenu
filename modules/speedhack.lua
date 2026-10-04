local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local SpeedHack = {}

local MIN_SPEED = 0.1
local MAX_SPEED = 5.0
local UNCHANGED_TOLERANCE = 0.01

SpeedHack.MIN = MIN_SPEED
SpeedHack.MAX = MAX_SPEED
SpeedHack.PRESETS = { 0.25, 0.5, 1.0, 2.0, 3.0, 5.0 }

--- Reports whether this CrabeLoader build exposes the game clock hook.
function SpeedHack.isAvailable()
    local gameSpeed = Crabe.GameSpeed
    return type(gameSpeed) == "table" and type(gameSpeed.set) == "function" and type(gameSpeed.get) == "function"
end

--- Returns the current simulation multiplier, 1.0 when the hook is unavailable.
function SpeedHack.getSpeed()
    if not SpeedHack.isAvailable() then return 1.0 end
    return tonumber(Native.poll(Crabe.GameSpeed.get)) or 1.0
end

--- Sets the simulation multiplier, clamped to the supported range.
function SpeedHack.setSpeed(multiplier)
    if not SpeedHack.isAvailable() then
        return Native.fail("Game speed: Crabe.GameSpeed is not provided by this CrabeLoader build")
    end

    multiplier = math.max(MIN_SPEED, math.min(MAX_SPEED, tonumber(multiplier) or 1.0))
    if not Native.run("Crabe.GameSpeed.set", Crabe.GameSpeed.set, multiplier) then return false end

    if math.abs(multiplier - 1.0) <= UNCHANGED_TOLERANCE then
        State.setStatus("Game speed back to normal", "info")
    else
        State.setStatus(string.format("Game speed x%.2f", multiplier), "success")
    end
    return true
end

--- Returns the simulation to normal speed.
function SpeedHack.reset()
    return SpeedHack.setSpeed(1.0)
end

return SpeedHack
