local Theme = {}

Theme.FONT = { DEFAULT = 0, BODY = 1, DISPLAY = 2 }
Theme.ALIGN = { LEFT = 0, CENTER = 1, RIGHT = 2 }

Theme.PALETTE = {
    night = { 6, 12, 40 },
    panel = { 11, 22, 62 },
    royal = { 30, 70, 190 },
    violet = { 118, 52, 220 },
    cyan = { 64, 224, 255 },
    ice = { 196, 245, 255 },
    gold = { 255, 204, 72 },
    white = { 244, 247, 255 },
    muted = { 140, 160, 208 },
    green = { 60, 224, 124 },
    red = { 255, 92, 108 },
    black = { 0, 0, 0 },
}

Theme.STATUS = {
    info = "cyan",
    success = "green",
    warning = "gold",
    error = "red",
}

local scale = 1
local originX, originY = 0, 0
local opacity = 1

local function pack(r, g, b, a)
    return ((a * 256 + b) * 256 + g) * 256 + r
end

--- Starts a frame: design units are multiplied by `factor` and offset by the origin,
--- and every alpha is multiplied by `alpha` (used for the open fade).
function Theme.beginFrame(factor, x, y, alpha)
    scale, originX, originY, opacity = factor, x or 0, y or 0, alpha or 1
end

--- Returns a packed colour from a palette name and an alpha between 0 and 255.
function Theme.color(name, alpha)
    local rgb = Theme.PALETTE[name] or Theme.PALETTE.white
    local a = math.floor(math.max(0, math.min(255, (alpha or 255) * opacity)) + 0.5)
    return pack(rgb[1], rgb[2], rgb[3], a)
end

local function sx(x) return originX + x * scale end
local function sy(y) return originY + y * scale end

function Theme.rect(x, y, w, h, color, rounding, thickness)
    ImGui.DrawRect(sx(x), sy(y), w * scale, h * scale, color, (rounding or 0) * scale, thickness or 0)
end

function Theme.gradient(x, y, w, h, from, to, horizontal)
    ImGui.DrawGradient(sx(x), sy(y), w * scale, h * scale, from, to, horizontal == true)
end

function Theme.line(x1, y1, x2, y2, color, thickness)
    ImGui.DrawLine(sx(x1), sy(y1), sx(x2), sy(y2), color, math.max(1, (thickness or 1) * scale))
end

function Theme.circle(x, y, radius, color, thickness)
    ImGui.DrawCircle(sx(x), sy(y), radius * scale, color, (thickness or 0) * scale)
end

--- Draws text whose top-left is (x, y), or aligned inside a box `width` wide.
--- Text that does not fit the box ends with "...".
function Theme.text(x, y, text, color, size, font, align, width, shadow)
    ImGui.DrawText(sx(x), sy(y), tostring(text), color, size * scale, font or Theme.FONT.BODY,
        align or Theme.ALIGN.LEFT, (width or 0) * scale, shadow or 0)
end

--- Draws text vertically centred in a row of the given height.
function Theme.rowText(x, y, rowHeight, text, color, size, align, width, font)
    Theme.text(x, y + (rowHeight - size) / 2, text, color, size, font, align, width)
end

return Theme
