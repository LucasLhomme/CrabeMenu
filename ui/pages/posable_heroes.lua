local Loader = ...
local Items = Loader.load("ui.items")
local List = Loader.load("ui.pages.list")
local PosableHeroes = Loader.load("modules.posable_heroes")
local Menu = Loader.load("ui.menu")

local function labels(values, format)
    local out = {}
    for index, value in ipairs(values) do out[index] = string.format(format, value) end
    return out
end

local ANGLE_LABELS = labels(PosableHeroes.ANGLES, "%d deg")
local SCALE_LABELS = labels(PosableHeroes.SCALES, "x%g")
local STEP_LABELS = labels(PosableHeroes.STEPS, "%g m")
local NUDGE = { "<", "<  hold  >", ">" }

--- A row that calls apply(-1) on left and apply(1) on right, again and again while the key is held.
local function nudge(label, apply, hint)
    return Items.choice(label, NUDGE, function() return 2 end, function(index) apply(index == 3 and 1 or -1) end, hint)
end

local spawnPage = List.page("Spawn Posable Hero", PosableHeroes.characters, {
    fields = { "label", "id" },
    toItem = function(entry)
        return Items.action(entry.label, function() PosableHeroes.spawn(entry) end,
            "Spawns " .. entry.id .. " in front of you", entry.id)
    end,
    emptyLabel = "No hero found",
    emptyHint = "The hero catalog (presentation/virtualreaderpc_data.lua) could not be read",
})

local function eventPage(hero)
    return List.page("Animation Events", PosableHeroes.events, {
        fields = { "id" },
        toItem = function(entry)
            return Items.action(entry.label, function() PosableHeroes.playEvent(hero, entry.id) end,
                "Sends " .. entry.id .. "; a hero with no player ignores most events")
        end,
        emptyLabel = "No event listed",
        emptyHint = "characters/biped/biped.animtreeproject could not be read",
    })
end

local function editorPage(hero)
    local items = {
        Items.section("Placement"),
        Items.action("Bring in front of me", function() PosableHeroes.bringToPlayer(hero) end,
            "Moves the hero 3 m ahead of you, facing you"),
        Items.action("Place at camera", function() PosableHeroes.placeAtCamera(hero) end,
            "Puts the hero where the camera is: fly the free camera (F1) to any spot first"),
        Items.action("Place at crosshair", function() PosableHeroes.placeAtCrosshair(hero) end,
            "Puts the hero on the spot under the crosshair (needs the Dev Toolkit plugin)"),
        Items.choice("Step", STEP_LABELS, function() return PosableHeroes.stepIndex end,
            function(index) PosableHeroes.stepIndex = index end, "Distance of each move below"),
        nudge("Back / forward", function(dir) PosableHeroes.move(hero, dir, 0, 0) end,
            "Hold left or right: moves along the camera's view"),
        nudge("Left / right", function(dir) PosableHeroes.move(hero, 0, dir, 0) end, "Hold left or right"),
        nudge("Down / up", function(dir) PosableHeroes.move(hero, 0, 0, dir) end, "Hold left or right"),
        Items.choice("Rotation", ANGLE_LABELS, function() return hero.angleIndex end,
            function(index) PosableHeroes.setAngle(hero, index) end, "Left/right turns by 15 degrees"),
        Items.action("Face me", function() PosableHeroes.faceMe(hero) end, "Turns the hero toward you"),
        Items.choice("Size", SCALE_LABELS, function() return hero.scaleIndex end,
            function(index) PosableHeroes.setScale(hero, index) end),
        Items.toggle("Collision", function() return hero.collision end,
            function(on) PosableHeroes.setCollision(hero, on) end, "Off lets you walk through it"),
        Items.section("Pose"),
        Items.toggle("Freeze pose", function() return PosableHeroes.isFrozen(hero) end,
            function(on) PosableHeroes.setFrozen(hero, on) end, "Stops the hero in its current pose, like a statue"),
        Items.submenu("Animation events (experimental)", eventPage(hero),
            "Events of the hero animation tree; most are ignored by a hero with no player",
            function() return tostring(#PosableHeroes.events()) end),
        Items.section("Delete"),
        Items.action("Remove", function()
            PosableHeroes.remove(hero)
            Menu.back()
        end, "Deletes this hero"),
    }
    return { title = hero.label, items = function() return items end }
end

local editors = setmetatable({}, { __mode = "k" })

local function editorFor(hero)
    editors[hero] = editors[hero] or editorPage(hero)
    return editors[hero]
end

local UNAVAILABLE = {
    Items.info("Posable heroes unavailable", nil, "Update CrabeLoader: this build has no Crabe.callNative"),
}

local built, builtRevision = nil, nil

return {
    title = "Posable Heroes",
    items = function()
        if not PosableHeroes.isAvailable() then return UNAVAILABLE end
        if builtRevision == PosableHeroes.store.revision then return built end
        local items = {
            Items.submenu("Spawn posable hero", spawnPage, "Pick a playable hero to place in front of you"),
            Items.action("Remove all", PosableHeroes.removeAll,
                "Deletes every posable hero, even the ones spawned before a mod reload (F4)"),
            Items.section("Placed"),
        }
        if #PosableHeroes.placed == 0 then
            items[#items + 1] = Items.info("None yet", nil, "Spawn one, then pick it here to configure it")
        end
        for index, hero in ipairs(PosableHeroes.placed) do
            items[#items + 1] = Items.submenu(string.format("%d. %s", index, hero.label),
                function() return editorFor(hero) end, "Position, rotation, size, pose")
        end
        built, builtRevision = items, PosableHeroes.store.revision
        return items
    end,
}
