local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Avatar = Loader.load("modules.avatar")

local SpeedHack = {}

local MIN_SPEED = 0.1
local MAX_SPEED = 5.0
local MAX_PLAYER_SPEED = 10.0
local UNCHANGED_TOLERANCE = 0.01

SpeedHack.MIN = MIN_SPEED
SpeedHack.MAX = MAX_SPEED
SpeedHack.PRESETS = { 0.25, 0.5, 1.0, 2.0, 3.0, 5.0 }
SpeedHack.PLAYER_PRESETS = { 1.0, 1.5, 2.0, 3.0, 5.0, 10.0 }

local REAPPLY_INTERVAL = 30
local playerSpeed = 1.0
local playerTicks = 0

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

--- Reports whether this CrabeLoader build can scale a single actor's movement speed.
function SpeedHack.isPlayerSpeedAvailable()
    return type(Game.SetActorSpeedScale) == "function" and type(Game.ActorSpeedScale) == "function"
end

--- Returns the movement speed multiplier chosen for the hero, 1.0 when none.
function SpeedHack.getPlayerSpeed()
    return playerSpeed
end

local function writePlayerSpeed(handle)
    local current = Native.poll(Game.ActorSpeedScale, handle)
    if current and math.abs(current - playerSpeed) < 0.001 then return true end
    return Native.poll(Game.SetActorSpeedScale, handle, playerSpeed) == true
end

--- Makes the hero alone run faster or slower; the choice is kept and reapplied when a world loads.
--- Reports the multiplier read back from the game, not the one asked for.
function SpeedHack.setPlayerSpeed(multiplier)
    if not SpeedHack.isPlayerSpeedAvailable() then
        return Native.fail("Hero speed: this CrabeLoader build has no per-actor speed (update CrabeLoader)")
    end

    playerSpeed = math.max(MIN_SPEED, math.min(MAX_PLAYER_SPEED, tonumber(multiplier) or 1.0))
    local handle = Avatar.handle()
    if not handle then
        State.setStatus(string.format("Hero speed x%.2f, applied when a world loads", playerSpeed), "info")
        return true
    end

    if not Native.run("Game.SetActorSpeedScale", Game.SetActorSpeedScale, handle, playerSpeed) then return false end

    local applied = Native.poll(Game.ActorSpeedScale, handle)
    if not applied or math.abs(applied - playerSpeed) > 0.001 then
        return Native.fail("Hero speed: the game did not keep the value (reads " .. tostring(applied) .. ")")
    end

    State.setStatus(math.abs(playerSpeed - 1.0) <= UNCHANGED_TOLERANCE and "Hero speed back to normal"
        or string.format("Hero speed x%.2f", playerSpeed), "success")
    return true
end

--- Per-frame upkeep: puts the chosen hero speed back after a world load recreated the movement data.
function SpeedHack.onTick()
    if not SpeedHack.isPlayerSpeedAvailable() then return end
    playerTicks = playerTicks + 1
    if playerTicks % REAPPLY_INTERVAL ~= 0 then return end

    local handle = Avatar.handle()
    if handle then writePlayerSpeed(handle) end
end

return SpeedHack
