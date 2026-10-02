local Loader = ...
local Theme = Loader.load("ui.theme")
local FreeCam = Loader.load("modules.freecam")
local WorldModule = Loader.load("modules.world")

local PLAYSET_LIST_HEIGHT = 120
local THEME_LIST_HEIGHT = 90

local function drawFreeCam()
    Theme.subHeader("Free camera")
    if Theme.button(FreeCam.isActive() and "Stop free camera" or "Start free camera", 180) then FreeCam.toggle() end
    ImGui.SameLine()
    if Theme.button("Teleport avatar to camera", 220) then FreeCam.teleportPlayerToCamera() end
end

local function drawPlaysets()
    Theme.subHeader(string.format("Play Sets (%d)", #WorldModule.PLAYSETS))
    if Theme.button("Unlock all Play Sets", 220) then WorldModule.unlockAllPlaysets() end

    ImGui.BeginChild("PlaysetsChild", 0, PLAYSET_LIST_HEIGHT, true)
    for _, playset in ipairs(WorldModule.PLAYSETS) do
        if ImGui.Selectable("Unlock: " .. playset.label .. "##" .. playset.key, false) then
            WorldModule.unlockPlayset(playset, true)
        end
    end
    ImGui.EndChild()
end

local function drawThemes()
    Theme.subHeader("Skydome themes")
    local themes = WorldModule.getThemes()
    if #themes == 0 then
        ImGui.TextDisabled("No skydome theme available.")
        return
    end

    ImGui.BeginChild("ThemesChild", 0, THEME_LIST_HEIGHT, true)
    for _, skydome in ipairs(themes) do
        if ImGui.Selectable(skydome.label .. "##" .. skydome.id, false) then WorldModule.applyTheme(skydome) end
    end
    ImGui.EndChild()
end

local function render()
    Theme.header("World & Travel")
    drawFreeCam()
    drawPlaysets()
    drawThemes()
end

return { title = "World", render = render }
