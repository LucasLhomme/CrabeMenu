local Config = {}

Config.VERSION = "2.1.0"
Config.NAME = "CrabeMenu"
Config.AUTHOR = "Lucas Lhomme"

local VK = {
    UP = 0x26, DOWN = 0x28, LEFT = 0x25, RIGHT = 0x27,
    ENTER = 0x0D, BACKSPACE = 0x08, ESCAPE = 0x1B, TAB = 0x09,
    PAGE_UP = 0x21, PAGE_DOWN = 0x22, HOME = 0x24, END = 0x23,
    F5 = 0x74, F6 = 0x75,
}

Config.KEYS = {
    MENU_TOGGLE = VK.F5,
    OVERLAY_TOGGLE = VK.F6,
}

Config.NAV_KEYS = {
    VK.UP, VK.DOWN, VK.LEFT, VK.RIGHT, VK.ENTER, VK.BACKSPACE,
    VK.PAGE_UP, VK.PAGE_DOWN, VK.HOME, VK.END, VK.ESCAPE, VK.TAB,
}

Config.UI = {
    MENU_TITLE = "Crabe Menu",
    MENU_WIDTH = 620,
    MENU_HEIGHT = 540,
    OVERLAY_TITLE = "CrabeRuntimeOverlay",
    OVERLAY_WIDTH = 280,
    OVERLAY_MARGIN = 16,
    BUTTON_HEIGHT = 26,
    LIST_HEIGHT = 240,
    MAX_LIST_ROWS = 150,
    STATUS_LIFETIME = 8,
}

Config.IMGUI = {
    COND_ALWAYS = 1,
    COND_ONCE = 2,
    COND_FIRST_USE_EVER = 4,
    WINDOW_NO_TITLE_BAR = 1,
    WINDOW_NO_RESIZE = 2,
    WINDOW_NO_MOVE = 4,
    WINDOW_NO_COLLAPSE = 32,
    WINDOW_ALWAYS_AUTO_RESIZE = 64,
    WINDOW_NO_FOCUS_ON_APPEARING = 4096,
    WINDOW_NO_INPUTS = 197120,
}

Config.THEME = {
    ACCENT_CYAN   = { 0.00, 0.82, 1.00, 1.00 },
    ACCENT_GOLD   = { 1.00, 0.80, 0.10, 1.00 },
    ACCENT_PURPLE = { 0.65, 0.35, 0.95, 1.00 },
    ACCENT_RED    = { 0.95, 0.25, 0.25, 1.00 },
    ACCENT_GREEN  = { 0.20, 0.85, 0.45, 1.00 },
    TEXT_PRIMARY  = { 0.96, 0.97, 0.99, 1.00 },
    TEXT_MUTED    = { 0.60, 0.68, 0.78, 1.00 },
}

return Config
