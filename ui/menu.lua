local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Theme = Loader.load("ui.theme")

local Menu = {}

local TABS = {
    Loader.load("ui.tabs.player"),
    Loader.load("ui.tabs.spawners"),
    Loader.load("ui.tabs.animations"),
    Loader.load("ui.tabs.cheats"),
    Loader.load("ui.tabs.world"),
    Loader.load("ui.tabs.multiplayer"),
    Loader.load("ui.tabs.settings"),
}

local function drawStatusBar()
    ImGui.Separator()
    local message, messageType = State.currentStatus()
    if message then
        Theme.textColored(Theme.statusColor(messageType), message)
    else
        Theme.textMuted("F5: close menu | F6: toggle overlay | mouse and gamepad supported")
    end
end

--- Draws the tabbed menu window; closing it with its button also releases the keys.
function Menu.render()
    ImGui.SetNextWindowSize(Config.UI.MENU_WIDTH, Config.UI.MENU_HEIGHT, Config.IMGUI.COND_FIRST_USE_EVER)

    local visible, open = ImGui.Begin(Config.UI.MENU_TITLE, true)
    if open == false then State.setMenuOpen(false) end

    if visible and open ~= false then
        if ImGui.BeginTabBar("CrabeMainTabBar") then
            for _, tab in ipairs(TABS) do
                if ImGui.BeginTabItem(tab.title) then
                    tab.render()
                    ImGui.EndTabItem()
                end
            end
            ImGui.EndTabBar()
        end
        drawStatusBar()
    end

    ImGui.End()
end

return Menu
