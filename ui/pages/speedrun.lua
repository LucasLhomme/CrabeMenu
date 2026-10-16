local Loader = ...
local Items = Loader.load("ui.items")
local Speedrun = Loader.load("modules.speedrun")
local Keybinds = Loader.load("core.keybinds")

local SLOT_LABELS = {}
for slot = 1, Speedrun.SLOT_COUNT do SLOT_LABELS[slot] = "Slot " .. slot end

local function toggleLabel()
    return Speedrun.isTimerRunning() and "Pause timer" or "Start timer"
end

local function selectedSlot()
    return Speedrun.selectedSlot
end

local function selectSlot(index)
    Speedrun.selectedSlot = index
end

local function saveSelected()
    Speedrun.savePosition(Speedrun.selectedSlot)
end

local function teleportSelected()
    Speedrun.teleportToSlot(Speedrun.selectedSlot)
end

local function slotText()
    return Speedrun.slotText(Speedrun.selectedSlot)
end

local TIMER_ITEMS = {
    Items.section("Timer"),
    Items.info("Time", Speedrun.timerText, "Shown in the overlay too (F6)"),
    Items.action(toggleLabel, Speedrun.toggleTimer, function() return "Starts or pauses the stopwatch (" .. Keybinds.label("timerToggle") .. ")" end),
    Items.action("Split", Speedrun.split, "Records the current time without stopping"),
    Items.action("Reset timer", Speedrun.resetTimer, "Stops the stopwatch and clears the splits"),
}

local PRACTICE_ITEMS = {
    Items.section("Practice"),
    Items.choice("Position slot", SLOT_LABELS, selectedSlot, selectSlot, "Which slot the two rows below and their hotkeys use"),
    Items.info("Saved position", slotText, "x, y, z of the selected slot"),
    Items.action("Save position here", saveSelected, function() return "Stores where your hero stands (" .. Keybinds.label("positionSave") .. ")" end),
    Items.action("Teleport to saved position", teleportSelected, function() return "Puts your hero back there, in the same world (" .. Keybinds.label("positionLoad") .. ")" end),
    Items.action("Reload this world", Speedrun.reloadWorld, function() return "Restarts the current world, keeping a Play Set save (" .. Keybinds.label("reloadWorld") .. ")" end),
}

local function splitItems()
    local list = {}
    for _, row in ipairs(Speedrun.recentSplits()) do
        list[#list + 1] = Items.info("Split " .. row.number, row.text)
    end
    return list
end

local function build()
    local list = {}
    for _, item in ipairs(TIMER_ITEMS) do list[#list + 1] = item end
    for _, item in ipairs(splitItems()) do list[#list + 1] = item end
    for _, item in ipairs(PRACTICE_ITEMS) do list[#list + 1] = item end
    return list
end

return {
    title = "Speedrun",
    items = build,
}
