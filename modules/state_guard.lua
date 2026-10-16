local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Avatar = Loader.load("modules.avatar")

local StateGuard = {}

local REAPPLY_INTERVAL = 15

--- Builds a switch that keeps one ActorState bit on the hero; options: label, modes = { { label, state } }.
--- The bit is put back every few frames, because a respawn, hero swap or zone change drops it.
function StateGuard.new(options)
    local guard = { MODES = options.modes }
    local enabled = false
    local modeIndex = 1
    local ticks = 0

    local function stateOf(index)
        return guard.MODES[index].state
    end

    local function hasState(handle, state)
        return Native.poll(Game.ActorHasState, handle, state) == true
    end

    local function applyState(handle)
        local state = stateOf(modeIndex)
        if hasState(handle, state) then return true end
        Native.poll(Game.SetActorState, handle, state, true)
        return hasState(handle, state)
    end

    local function releaseStates(handle)
        for _, mode in ipairs(guard.MODES) do
            if hasState(handle, mode.state) then Native.poll(Game.SetActorState, handle, mode.state, false) end
        end
    end

    --- Reports whether this CrabeLoader build can read and set actor states.
    function guard.isAvailable()
        return type(Game.SetActorState) == "function" and type(Game.ActorHasState) == "function"
    end

    --- Reports whether the switch is on.
    function guard.isEnabled()
        return enabled
    end

    --- Returns the index of the chosen mode in guard.MODES.
    function guard.getMode()
        return modeIndex
    end

    --- Chooses the mode and re-applies it if the switch is on.
    function guard.setMode(index)
        local handle = Avatar.handle()
        if handle then releaseStates(handle) end
        modeIndex = index
        if enabled and handle and not applyState(handle) then
            return Native.fail(options.label .. ": the game refused the state")
        end
        State.setStatus(options.label .. " mode: " .. guard.MODES[index].label, "info")
        return true
    end

    --- Turns the switch on or off; with no avatar loaded it is applied as soon as one is.
    --- Reports failure when the game does not confirm the state on the avatar.
    function guard.setEnabled(on)
        if not guard.isAvailable() then
            return Native.fail(options.label .. ": this CrabeLoader build cannot set actor states (update CrabeLoader)")
        end

        enabled = on == true
        local handle = Avatar.handle()
        if not handle then
            State.setStatus(options.label .. (enabled and " armed, applied when a world loads" or " OFF"), "info")
            return true
        end

        if not enabled then
            releaseStates(handle)
            State.setStatus(options.label .. " OFF", "info")
            return true
        end

        if not applyState(handle) then
            enabled = false
            return Native.fail(options.label .. ": the game did not accept the " .. stateOf(modeIndex) .. " state")
        end
        State.setStatus(options.label .. " ON (" .. guard.MODES[modeIndex].label .. ")", "success")
        return true
    end

    --- Per-frame upkeep: puts the state back after anything dropped it.
    function guard.onTick()
        if not enabled then return end
        ticks = ticks + 1
        if ticks % REAPPLY_INTERVAL ~= 0 then return end

        local handle = Avatar.handle()
        if handle then applyState(handle) end
    end

    return guard
end

return StateGuard
