local Loader = ...
local Config = Loader.load("core.config")

local Theme = {}

local COLORS = Config.THEME

local BADGE_COLORS = {
    cyan = COLORS.ACCENT_CYAN,
    gold = COLORS.ACCENT_GOLD,
    green = COLORS.ACCENT_GREEN,
    red = COLORS.ACCENT_RED,
    purple = COLORS.ACCENT_PURPLE,
    muted = COLORS.TEXT_MUTED,
}

local STATUS_COLORS = {
    info = COLORS.ACCENT_CYAN,
    success = COLORS.ACCENT_GREEN,
    warning = COLORS.ACCENT_GOLD,
    error = COLORS.ACCENT_RED,
}

--- Draws text in an RGBA color.
function Theme.textColored(color, text)
    ImGui.TextColored(color[1], color[2], color[3], color[4], tostring(text))
end

function Theme.textPrimary(text) Theme.textColored(COLORS.TEXT_PRIMARY, text) end
function Theme.textMuted(text) Theme.textColored(COLORS.TEXT_MUTED, text) end
function Theme.textCyan(text) Theme.textColored(COLORS.ACCENT_CYAN, text) end
function Theme.textGold(text) Theme.textColored(COLORS.ACCENT_GOLD, text) end
function Theme.textRed(text) Theme.textColored(COLORS.ACCENT_RED, text) end

--- Returns the color that goes with a status type.
function Theme.statusColor(statusType)
    return STATUS_COLORS[statusType] or COLORS.ACCENT_CYAN
end

--- Draws a tab title followed by a separator.
function Theme.header(title)
    Theme.textGold(title:upper())
    ImGui.Separator()
    ImGui.Spacing()
end

--- Draws a section title followed by a separator.
function Theme.subHeader(title)
    ImGui.Spacing()
    Theme.textCyan(title)
    ImGui.Separator()
end

--- Draws a compact colored tag such as [GOD ON].
function Theme.badge(label, colorName)
    Theme.textColored(BADGE_COLORS[colorName] or COLORS.ACCENT_CYAN, "[" .. label .. "]")
end

--- Draws a standard-height button and returns whether it was clicked.
function Theme.button(label, width)
    return ImGui.Button(label, width or 0, Config.UI.BUTTON_HEIGHT)
end

--- Draws a scrolling list of selectable rows, capped so a huge catalog stays cheap.
--- describe(row) gives the row text; onPick(row) runs when it is clicked.
function Theme.selectList(id, rows, describe, onPick, emptyText)
    ImGui.BeginChild(id, 0, Config.UI.LIST_HEIGHT, true)

    if #rows == 0 then ImGui.TextDisabled(emptyText) end

    local shown = math.min(#rows, Config.UI.MAX_LIST_ROWS)
    for i = 1, shown do
        if ImGui.Selectable(describe(rows[i]) .. "##" .. i, false) then onPick(rows[i]) end
    end
    if #rows > shown then
        ImGui.TextDisabled(string.format("... %d more, narrow the search", #rows - shown))
    end

    ImGui.EndChild()
end

return Theme
