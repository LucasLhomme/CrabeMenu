local Loader = ...
local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Input = Loader.load("core.input")
local Theme = Loader.load("ui.theme")
local Items = Loader.load("ui.items")

local Menu = {}

local L = Config.LAYOUT
local FONT, ALIGN = Theme.FONT, Theme.ALIGN
local LABEL_X = 20
local VALUE_WIDTH = 180
local PROMPT_HEIGHT = 118
local PROMPT_MIN_ROWS = 4
local PROMPT_VISIBLE_CHARS = 32
local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1920, 1080

local STARS = {
    { 0.05, 0.20, 1.6, 2.1 }, { 0.13, 0.62, 1.1, 3.3 }, { 0.21, 0.30, 2.0, 1.7 }, { 0.30, 0.78, 1.2, 2.8 },
    { 0.37, 0.14, 1.0, 3.9 }, { 0.62, 0.12, 1.3, 2.4 }, { 0.70, 0.70, 1.8, 1.9 }, { 0.78, 0.26, 1.1, 3.1 },
    { 0.86, 0.58, 1.5, 2.6 }, { 0.93, 0.18, 1.9, 1.5 }, { 0.47, 0.86, 1.0, 3.6 }, { 0.56, 0.42, 0.9, 4.2 },
}
local GLOW_OFFSETS = { { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }

local KEYBOARD_LEGEND = "\226\134\145\226\134\147 Move    \226\134\144\226\134\146 Change    Enter Select    Esc Back"
local PAD_LEGEND = "D-pad Move    A Select    B Back    LT/RT Page    RB+\226\134\144 Close"
local PROMPT_LEGEND = "Enter Confirm    Esc Cancel    Backspace Erase"

local root = nil
local stack = {}
local items = {}
local prompt = nil
local openedAt = 0
local highlightSlot = 1

local function current()
    return stack[#stack]
end

local function selectable(item)
    return item ~= nil and item.kind ~= "section"
end

local function nearest(index, direction)
    local count = #items
    if count == 0 then return 1 end
    index = math.max(1, math.min(count, index))
    for i = index, (direction > 0) and count or 1, direction do
        if selectable(items[i]) then return i end
    end
    for i = index, (direction > 0) and 1 or count, -direction do
        if selectable(items[i]) then return i end
    end
    return index
end

local function wrapStep(direction)
    local count = #items
    local index = current().cursor
    for _ = 1, count do
        index = (index - 1 + direction) % count + 1
        if selectable(items[index]) then return index end
    end
    return current().cursor
end

local function keepVisible(frame)
    local count = #items
    frame.cursor = nearest(frame.cursor, 1)
    if frame.cursor > frame.scroll + L.MAX_ROWS then frame.scroll = frame.cursor - L.MAX_ROWS end
    if frame.cursor <= frame.scroll then frame.scroll = frame.cursor - 1 end
    frame.scroll = math.max(0, math.min(math.max(0, count - L.MAX_ROWS), frame.scroll))
end

local function refresh()
    items = current().page.items() or {}
    keepVisible(current())
end

local function push(page)
    stack[#stack + 1] = { page = page, cursor = 1, scroll = 0 }
    refresh()
    highlightSlot = current().cursor - current().scroll
end

local function pop()
    stack[#stack] = nil
    refresh()
    highlightSlot = current().cursor - current().scroll
end

local function finishPrompt()
    prompt = nil
    State.setTyping(false)
    Input.swallowHeld()
end

local function startPrompt(item)
    local text = tostring(Items.resolve(item.get) or "")
    prompt = { item = item, text = text, original = text }
    State.setTyping(true, Input.TEXT_KEYS)
    Input.primeTyping()
    Input.swallowHeld()
end

local function cycle(item, step)
    local count = #item.options
    if count == 0 then return end
    item.set(((item.get() or 1) - 1 + step) % count + 1)
end

local function activate(item)
    if item.kind == "action" then
        item.run()
    elseif item.kind == "toggle" then
        item.set(not item.get())
    elseif item.kind == "submenu" then
        push(Items.resolve(item.page))
    elseif item.kind == "choice" then
        cycle(item, 1)
    elseif item.kind == "input" then
        startPrompt(item)
    end
end

local function updatePrompt(dt)
    local fired = Input.typing(dt)
    local item = prompt.item
    local before = prompt.text

    local typed = Input.typedCharacters()
    if typed ~= "" then prompt.text = (prompt.text .. typed):sub(1, Config.UI.MAX_INPUT_LENGTH) end
    if fired.erase then prompt.text = prompt.text:sub(1, -2) end
    if item.live and prompt.text ~= before then item.set(prompt.text) end

    if fired.cancel then
        if item.live then item.set(prompt.original) end
        finishPrompt()
    elseif fired.confirm then
        local text = prompt.text
        finishPrompt()
        item.set(text)
    end
end

local function navigate(dt)
    local fired = Input.navigation(dt)
    local frame = current()
    local item = items[frame.cursor]

    if fired.up then frame.cursor = wrapStep(-1) end
    if fired.down then frame.cursor = wrapStep(1) end
    if fired.pageUp then frame.cursor = nearest(frame.cursor - L.PAGE_JUMP, -1) end
    if fired.pageDown then frame.cursor = nearest(frame.cursor + L.PAGE_JUMP, 1) end
    if fired.first then frame.cursor = nearest(1, 1) end
    if fired.last then frame.cursor = nearest(#items, -1) end

    if selectable(item) and (fired.left or fired.right) then
        if item.kind == "choice" then cycle(item, fired.left and -1 or 1) end
        if item.kind == "toggle" then item.set(fired.right == true) end
    end
    if fired.select and selectable(item) then activate(item) end

    if fired.back then
        if #stack > 1 then pop() else Menu.setOpen(false) end
    end
end

--- Sets the page the menu opens on.
function Menu.setRoot(page)
    root = page
    stack = {}
end

--- Opens or closes the menu, keeping the page and row it was on.
function Menu.setOpen(open)
    open = (open == true)
    if open == State.isMenuOpen then return end

    if open then
        if #stack == 0 then stack = { { page = root, cursor = 1, scroll = 0 } } end
        openedAt = State.gameClock
        Input.swallowHeld()
    elseif prompt then
        finishPrompt()
    end
    State.setMenuOpen(open)
end

--- Reads the controls for this tick and moves the menu; call once per tick.
function Menu.update(dt)
    if Input.menuToggled() then Menu.setOpen(not State.isMenuOpen) end
    if not State.isMenuOpen or not root then return end

    refresh()
    if prompt then updatePrompt(dt) else navigate(dt) end
    if not State.isMenuOpen then return end

    refresh()
    local target = current().cursor - current().scroll
    highlightSlot = highlightSlot + (target - highlightSlot) * math.min(1, dt * L.HIGHLIGHT_SPEED)
end

local function drawBanner(x, y, w)
    local h = L.BANNER_HEIGHT
    if Theme.image(Config.BANNER_IMAGE, x, y, w, h) then return end

    Theme.gradient(x, y, w, h, Theme.color("royal", 250), Theme.color("violet", 250), true)
    Theme.gradient(x, y + h * 0.4, w, h * 0.6, Theme.color("night", 0), Theme.color("night", 150))

    for index, star in ipairs(STARS) do
        local twinkle = 0.55 + 0.45 * math.sin(State.gameClock * star[4] + index)
        Theme.circle(x + star[1] * w, y + star[2] * h, star[3], Theme.color("white", 210 * twinkle))
    end
    Theme.text(x + w - 100, y - 14, "\226\136\158", Theme.color("ice", 36), 110, FONT.DISPLAY)

    local title = Config.NAME:upper():gsub("MENU$", " MENU")
    for _, offset in ipairs(GLOW_OFFSETS) do
        Theme.text(x + offset[1], y + 16 + offset[2], title, Theme.color("cyan", 70), 50, FONT.DISPLAY, ALIGN.CENTER, w)
    end
    Theme.text(x, y + 16, title, Theme.color("white"), 50, FONT.DISPLAY, ALIGN.CENTER, w, Theme.color("night", 170))
    Theme.text(x, y + 78, "D I S N E Y   I N F I N I T Y   3 . 0", Theme.color("gold"), 14, FONT.BODY, ALIGN.CENTER, w)
    Theme.rect(x, y + h - 3, w, 3, Theme.color("gold"))
end

local function breadcrumb()
    local parts = {}
    for index = math.max(1, #stack - 1), #stack do
        parts[#parts + 1] = tostring(Items.resolve(stack[index].page.title)):upper()
    end
    return table.concat(parts, "  \226\128\186  ")
end

local function selectableCount()
    local count, position = 0, 0
    for index, item in ipairs(items) do
        if selectable(item) then
            count = count + 1
            if index == current().cursor then position = count end
        end
    end
    return position, count
end

local function drawSubheader(x, y, w)
    local h = L.SUBHEADER_HEIGHT
    Theme.rect(x, y, w, h, Theme.color("night", 245))
    Theme.rowText(x + LABEL_X, y, h, breadcrumb(), Theme.color("cyan"), 16, ALIGN.LEFT, w - 120)

    local position, count = selectableCount()
    Theme.rowText(x, y, h, string.format("%d / %d", position, count), Theme.color("muted"), 15, ALIGN.RIGHT, w - 16)
end

local function drawSwitch(x, y, on, selected)
    local fill = on and Theme.color("green") or Theme.color(selected and "night" or "muted", 80)
    Theme.rect(x, y, 42, 22, fill, 11)
    Theme.circle(on and (x + 31) or (x + 11), y + 11, 8, Theme.color("white"))
end

local function drawSection(item, x, y, w)
    Theme.rowText(x + LABEL_X, y + 4, L.ROW_HEIGHT, tostring(item.label):upper(), Theme.color("gold"), 14, ALIGN.LEFT, w)
    Theme.rect(x + LABEL_X, y + L.ROW_HEIGHT - 6, w - 2 * LABEL_X, 1, Theme.color("gold", 70))
end

local function drawValue(text, x, y, w, color, size)
    Theme.rowText(x + w - 16 - VALUE_WIDTH, y, L.ROW_HEIGHT, text, color, size or 17, ALIGN.RIGHT, VALUE_WIDTH)
end

local function drawRow(item, x, y, w, selected)
    if item.kind == "section" then return drawSection(item, x, y, w) end

    local ink = Theme.color(selected and "night" or "white")
    local soft = selected and Theme.color("night", 190) or Theme.color("cyan")
    local labelInk = (item.kind == "info" and not selected) and Theme.color("muted") or ink
    local labelWidth = w - LABEL_X - VALUE_WIDTH - 24
    local value = Items.resolve(item.value)

    if item.kind == "submenu" then
        labelWidth = w - LABEL_X - 48 - (value and 110 or 0)
        Theme.rowText(x, y - 3, L.ROW_HEIGHT, "\226\128\186", ink, 30, ALIGN.RIGHT, w - 18)
        if value then Theme.rowText(x, y, L.ROW_HEIGHT, tostring(value), soft, 15, ALIGN.RIGHT, w - 46) end
    elseif item.kind == "toggle" then
        labelWidth = w - LABEL_X - 80
        drawSwitch(x + w - 16 - 42, y + (L.ROW_HEIGHT - 22) / 2, item.get() == true, selected)
    elseif item.kind == "choice" then
        local text = tostring(item.options[item.get() or 1] or "?")
        if selected then text = "\226\128\185  " .. text .. "  \226\128\186" end
        drawValue(text, x, y, w, soft, 18)
    elseif item.kind == "input" then
        local text = tostring(Items.resolve(item.get) or "")
        drawValue(text ~= "" and text or "\226\128\148", x, y, w, soft)
    elseif value ~= nil then
        drawValue(tostring(value), x, y, w, soft)
    else
        labelWidth = w - 2 * LABEL_X
    end

    Theme.rowText(x + LABEL_X, y, L.ROW_HEIGHT, tostring(Items.resolve(item.label)), labelInk, 20, ALIGN.LEFT, labelWidth)
end

local function drawPrompt(x, top, w, bodyHeight)
    Theme.rect(x, top, w, bodyHeight, Theme.color("night", 215))

    local bx, bw = x + 18, w - 36
    local by = top + math.max(8, (bodyHeight - PROMPT_HEIGHT) / 2)
    Theme.rect(bx, by, bw, PROMPT_HEIGHT, Theme.color("panel", 252), 8)
    Theme.rect(bx, by, bw, PROMPT_HEIGHT, Theme.color("cyan", 210), 8, 1)
    Theme.text(bx + 16, by + 12, tostring(Items.resolve(prompt.item.label)), Theme.color("gold"), 16, FONT.BODY,
        ALIGN.LEFT, bw - 32)

    Theme.rect(bx + 14, by + 42, bw - 28, 38, Theme.color("night", 255), 6)
    local shown = prompt.text
    if #shown > PROMPT_VISIBLE_CHARS then shown = "..." .. shown:sub(-PROMPT_VISIBLE_CHARS) end
    local caret = (math.floor(State.gameClock * 2.5) % 2 == 0) and "|" or ""
    Theme.rowText(bx + 26, by + 42, 38, shown .. caret, Theme.color("white"), 19, ALIGN.LEFT, bw - 52)

    local note = (State.lastDevice == "pad") and "This field needs a keyboard" or "Type on the keyboard"
    Theme.text(bx + 16, by + 90, note, Theme.color("muted"), 13, FONT.BODY, ALIGN.LEFT, bw - 32)
end

local function drawRows(x, top, w)
    local frame = current()
    local rows = math.max(1, math.min(#items, L.MAX_ROWS))
    if prompt then rows = math.max(rows, PROMPT_MIN_ROWS) end
    local bodyHeight = rows * L.ROW_HEIGHT

    Theme.rect(x, top, w, bodyHeight, Theme.color("panel", 228))
    if #items == 0 then
        Theme.rowText(x, top, L.ROW_HEIGHT, "Nothing here yet", Theme.color("muted"), 18, ALIGN.CENTER, w)
    end

    if selectable(items[frame.cursor]) then
        local hy = top + (highlightSlot - 1) * L.ROW_HEIGHT
        Theme.gradient(x, hy, w, L.ROW_HEIGHT, Theme.color("cyan"), Theme.color("ice"), true)
        Theme.rect(x, hy, 4, L.ROW_HEIGHT, Theme.color("gold"))
    end

    for slot = 1, math.min(#items - frame.scroll, L.MAX_ROWS) do
        local index = frame.scroll + slot
        drawRow(items[index], x, top + (slot - 1) * L.ROW_HEIGHT, w, index == frame.cursor)
    end

    if prompt then drawPrompt(x, top, w, bodyHeight) end
    return top + bodyHeight
end

local function drawFooter(x, y, w)
    local h = L.FOOTER_HEIGHT
    local frame = current()
    Theme.rect(x, y, w, h, Theme.color("night", 245))
    Theme.rowText(x + LABEL_X, y, h, "v" .. Config.VERSION, Theme.color("muted"), 13, ALIGN.LEFT, 120)

    if #items > L.MAX_ROWS then
        local canUp = frame.scroll > 0
        local canDown = frame.scroll + L.MAX_ROWS < #items
        Theme.rowText(x, y, h, "\226\150\178", Theme.color("cyan", canUp and 255 or 50), 12, ALIGN.CENTER, w - 28)
        Theme.rowText(x + 28, y, h, "\226\150\188", Theme.color("cyan", canDown and 255 or 50), 12, ALIGN.CENTER, w - 28)
    end
    return y + h
end

local function legend()
    if prompt then return PROMPT_LEGEND end
    return (State.lastDevice == "pad") and PAD_LEGEND or KEYBOARD_LEGEND
end

local function drawHint(x, y, w)
    local item = items[current().cursor]
    local message, messageType = State.currentStatus()

    local text, color = nil, Theme.color("white")
    if message then
        text, color = message, Theme.color(Theme.STATUS[messageType] or "cyan")
    elseif selectable(item) then
        text = Items.resolve(item.hint)
    end

    Theme.rect(x, y, w, L.HINT_HEIGHT, Theme.color("panel", 235))
    Theme.rect(x, y, w, 2, Theme.color("gold", 220))
    if text and text ~= "" then
        Theme.text(x + LABEL_X, y + 9, text, color, 17, FONT.BODY, ALIGN.LEFT, w - 2 * LABEL_X)
    end
    Theme.text(x + LABEL_X, y + 34, legend(), Theme.color("muted"), 14, FONT.BODY, ALIGN.LEFT, w - 2 * LABEL_X)
end

--- Draws the menu; call from onDraw.
function Menu.render()
    if not State.isMenuOpen or #stack == 0 then return end

    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or screenWidth <= 0 then screenWidth, screenHeight = FALLBACK_WIDTH, FALLBACK_HEIGHT end
    local factor = screenHeight / L.DESIGN_HEIGHT * State.menuScale()
    local opacity = math.min(1, (State.gameClock - openedAt) / L.FADE_TIME)
    Theme.beginFrame(factor, 0, 0, opacity)

    local w = L.WIDTH
    local x = L.MARGIN_X
    if State.menuSide == "right" then x = screenWidth / factor - L.MARGIN_X - w end
    local y = L.MARGIN_Y

    drawBanner(x, y, w)
    y = y + L.BANNER_HEIGHT
    drawSubheader(x, y, w)
    y = drawRows(x, y + L.SUBHEADER_HEIGHT, w)
    y = drawFooter(x, y, w)
    drawHint(x, y + L.HINT_GAP, w)
end

return Menu
