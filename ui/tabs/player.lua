local Loader = ...
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")
local PlayerModule = Loader.load("modules.player")
local Cheats = Loader.load("modules.cheats")

local SPARK_AMOUNTS = {
    { label = "+50,000 Sparks", amount = 50000, width = 130 },
    { label = "+1,000,000 Sparks", amount = 1000000, width = 150 },
    { label = "+10,000,000 Sparks", amount = 10000000, width = 160 },
}

local function drawRoster()
    ImGui.BeginChild("HeroListChild", 0, 160, true)

    local roster = PlayerModule.getRoster()
    if #roster == 0 then ImGui.TextDisabled("No heroes available yet.") end

    for _, group in ipairs(roster) do
        Theme.textGold(group.title)
        for _, hero in ipairs(group.characters) do
            local label = string.format("%s  [SKU %s]##%s", hero.name, tostring(hero.sku), tostring(hero.sku))
            if ImGui.Selectable(label, State.avatarSku == hero.sku) then
                PlayerModule.swapCharacter(hero.sku, hero.name)
            end
        end
        ImGui.Spacing()
    end

    ImGui.EndChild()
end

local function render()
    Theme.header("Player & Heroes")
    Theme.textCyan(string.format("Current hero: %s  [SKU %s]", State.avatarName, tostring(State.avatarSku)))

    Theme.subHeader("Swap character")
    ImGui.Text("Apply route:")
    ImGui.SameLine()
    if Theme.button(State.applyRoute == "loadout" and "Loadout" or "Legacy", 110) then
        State.applyRoute = (State.applyRoute == "loadout") and "legacy" or "loadout"
        State.setStatus("Character swap route: " .. State.applyRoute, "info")
    end
    drawRoster()

    Theme.subHeader("Progression & health")
    if Theme.button("Level Up +1", 120) then PlayerModule.levelUp() end
    ImGui.SameLine()
    if Theme.button("Max Level", 120) then PlayerModule.maxProgression() end
    ImGui.SameLine()
    if Theme.button("Refill Health", 130) then Cheats.refillHealth() end

    Theme.subHeader("Sparks")
    for index, entry in ipairs(SPARK_AMOUNTS) do
        if index > 1 then ImGui.SameLine() end
        if Theme.button(entry.label, entry.width) then PlayerModule.addSparks(entry.amount) end
    end
end

return { title = "Player & Heroes", render = render }
