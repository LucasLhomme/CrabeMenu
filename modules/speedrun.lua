local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Input = Loader.load("core.input")
local Settings = Loader.load("core.settings")
local Keybinds = Loader.load("core.keybinds")
local WorldModule = Loader.load("modules.world")
local Avatar = Loader.load("modules.avatar")

local Speedrun = {}

local SLOT_COUNT = 3
local MAX_SPLITS = 5
local SECONDS_PER_MINUTE = 60

local timer = { running = false, elapsed = 0, splits = {} }
local slots = {}

Speedrun.SLOT_COUNT = SLOT_COUNT
Speedrun.selectedSlot = 1

local function inFrontEnd()
    local world = Native.poll(Game.CurrentWorld)
    return type(world) ~= "string" or world:lower() == "frontend"
end

--- Formats a duration in seconds as m:ss.cc.
function Speedrun.formatTime(seconds)
    local minutes = math.floor(seconds / SECONDS_PER_MINUTE)
    return string.format("%d:%05.2f", minutes, seconds - minutes * SECONDS_PER_MINUTE)
end

--- Returns the stopwatch reading as text.
function Speedrun.timerText()
    return Speedrun.formatTime(timer.elapsed)
end

--- Reports whether the stopwatch is running.
function Speedrun.isTimerRunning()
    return timer.running
end

--- Reports whether the stopwatch has a reading worth showing.
function Speedrun.hasTimerReading()
    return timer.running or timer.elapsed > 0
end

--- Starts the stopwatch, or pauses it when it is running.
function Speedrun.toggleTimer()
    timer.running = not timer.running
    State.setStatus(timer.running and "Timer started" or ("Timer paused at " .. Speedrun.timerText()), "info")
end

--- Stops the stopwatch and clears the reading and the splits.
function Speedrun.resetTimer()
    timer.running = false
    timer.elapsed = 0
    timer.splits = {}
    State.setStatus("Timer reset", "info")
end

--- Records the current reading as a split without stopping the stopwatch.
function Speedrun.split()
    if not Speedrun.hasTimerReading() then
        State.setStatus("Start the timer before splitting", "warning")
        return false
    end
    timer.splits[#timer.splits + 1] = timer.elapsed
    State.setStatus(string.format("Split %d: %s", #timer.splits, Speedrun.timerText()), "success")
    return true
end

--- Returns the latest splits, newest last, as { number = n, text = "m:ss.cc" } rows.
function Speedrun.recentSplits()
    local rows = {}
    for index = math.max(1, #timer.splits - MAX_SPLITS + 1), #timer.splits do
        rows[#rows + 1] = { number = index, text = Speedrun.formatTime(timer.splits[index]) }
    end
    return rows
end

--- Describes the position saved in a slot, or "empty".
function Speedrun.slotText(slot)
    local saved = slots[slot]
    if not saved then return "empty" end
    return string.format("%.1f, %.1f, %.1f", saved.x, saved.y, saved.z)
end

--- Stores the avatar's current position in a slot.
function Speedrun.savePosition(slot)
    local handle = Avatar.handle()
    if not handle then return Native.fail("Save position: no avatar in this world") end

    local x, y, z = Native.poll(Game.ActorPosition, handle)
    if not x then return Native.fail("Save position: the avatar position cannot be read") end

    slots[slot] = { x = x, y = y, z = z, world = Native.poll(Game.CurrentWorld) }
    State.setStatus(string.format("Position %d saved (%s)", slot, Speedrun.slotText(slot)), "success")
    return true
end

--- Teleports the avatar to the position stored in a slot.
function Speedrun.teleportToSlot(slot)
    local saved = slots[slot]
    if not saved then
        State.setStatus("Position " .. slot .. " is empty", "warning")
        return false
    end

    local handle = Avatar.handle()
    if not handle then return Native.fail("Teleport: no avatar in this world") end

    local world = Native.poll(Game.CurrentWorld)
    if saved.world and world and saved.world ~= world then
        State.setStatus("Position " .. slot .. " was saved in " .. tostring(saved.world), "warning")
        return false
    end

    if not Native.run("Game.PlaceActor", Game.PlaceActor, handle, saved.x, saved.y, saved.z) then return false end
    State.setStatus("Teleported to position " .. slot, "success")
    return true
end

--- Reloads the current world, keeping the Play Set save when it has one.
function Speedrun.reloadWorld()
    if inFrontEnd() then
        State.setStatus("No world to reload from the main menu", "warning")
        return false
    end
    return WorldModule.travelTo(Native.poll(Game.CurrentZone) or Native.poll(Game.CurrentWorld))
end

--- Advances the stopwatch and runs the hotkeys: save position, teleport back, start or pause, reload the world.
function Speedrun.onTick(dt)
    if timer.running then timer.elapsed = timer.elapsed + dt end

    if State.isTyping or Keybinds.isCapturing() then return end
    if Input.actionPressed("positionSave") then Speedrun.savePosition(Speedrun.selectedSlot) end
    if Input.actionPressed("positionLoad") then Speedrun.teleportToSlot(Speedrun.selectedSlot) end
    if Input.actionPressed("timerToggle") then Speedrun.toggleTimer() end
    if Input.actionPressed("reloadWorld") then Speedrun.reloadWorld() end
    if Input.actionPressed("hudToggle") then
        State.isSpeedrunHudOpen = not State.isSpeedrunHudOpen
        Settings.save()
        State.setStatus("Speedrun HUD " .. (State.isSpeedrunHudOpen and "on" or "off"), "info")
    end
end

return Speedrun
