local Loader = ...
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")
local Cheats = Loader.load("modules.cheats")
local SpeedHack = Loader.load("modules.speedhack")

local PRESETS_PER_ROW = 3
local SLIDER_TOLERANCE = 0.02

local function drawSpeed()
    Theme.subHeader("Game speed (slow motion / turbo)")
    if not SpeedHack.isAvailable() then
        ImGui.TextDisabled("Needs Crabe.GameSpeed, which this CrabeLoader build does not provide.")
        return
    end

    local current = SpeedHack.getSpeed()
    Theme.textCyan(string.format("Current multiplier: x%.2f", current))

    for index, value in ipairs(SpeedHack.PRESETS) do
        if Theme.button(string.format("x%.2f", value), 90) then SpeedHack.setSpeed(value) end
        if index % PRESETS_PER_ROW ~= 0 and index < #SpeedHack.PRESETS then ImGui.SameLine() end
    end

    local chosen = ImGui.SliderFloat("Live multiplier##SpeedSlider", current, SpeedHack.MIN, SpeedHack.MAX)
    if math.abs(chosen - current) > SLIDER_TOLERANCE then SpeedHack.setSpeed(chosen) end

    if Theme.button("Reset to normal speed", 200) then SpeedHack.reset() end
end

local function drawGodMode()
    Theme.subHeader("God Mode")
    local active = Cheats.isGodMode()
    if Theme.button(active and "God Mode: ON (click to disable)" or "God Mode: OFF (click to enable)", 260) then
        Cheats.setGodMode(not active)
    end

    if State.godLocked then
        if Theme.button("Release locked target", 200) then Cheats.unlockGodTarget() end
    else
        if Theme.button("Lock to last damaged target", 220) then Cheats.lockToLastDamaged() end
    end
end

local function drawEditor()
    Theme.subHeader("Toy Box editor")
    if Theme.button("Unlock editor everywhere", 220) then Cheats.unlockEditorEverywhere() end
end

local function render()
    Theme.header("Cheats & Time")
    drawSpeed()
    drawGodMode()
    drawEditor()
end

return { title = "Cheats", render = render }
