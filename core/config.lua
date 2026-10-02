local Config = {}

Config.VERSION = "1.0.0"
Config.NAME = "CrabeMenu"
Config.AUTHOR = "Lucas Lhomme"
Config.SETTINGS_FILE = "crabemenu_settings.json"

local VK = {
    BACKSPACE = 0x08, TAB = 0x09, ENTER = 0x0D, SHIFT = 0x10, ESCAPE = 0x1B, SPACE = 0x20,
    PAGE_UP = 0x21, PAGE_DOWN = 0x22, END = 0x23, HOME = 0x24,
    LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28, DELETE = 0x2E,
    NUMPAD_0 = 0x60, DECIMAL = 0x6E, F5 = 0x74, F6 = 0x75,
    OEM_COMMA = 0xBC, OEM_MINUS = 0xBD, OEM_PERIOD = 0xBE,
}
Config.VK = VK

Config.KEYS = {
    MENU_TOGGLE = VK.F5,
    OVERLAY_TOGGLE = VK.F6,
}

Config.NAV_KEYS = {
    VK.UP, VK.DOWN, VK.LEFT, VK.RIGHT, VK.ENTER, VK.BACKSPACE, VK.ESCAPE,
    VK.PAGE_UP, VK.PAGE_DOWN, VK.HOME, VK.END, VK.TAB,
}

Config.REPEAT = {
    DELAY = 0.38,
    INTERVAL = 0.065,
    FAST_INTERVAL = 0.03,
    FAST_AFTER = 1.6,
    STICK_THRESHOLD = 20000,
}

Config.LAYOUT = {
    DESIGN_HEIGHT = 1080,
    MARGIN_X = 64,
    MARGIN_Y = 72,
    WIDTH = 470,
    BANNER_HEIGHT = 112,
    SUBHEADER_HEIGHT = 36,
    ROW_HEIGHT = 40,
    MAX_ROWS = 11,
    FOOTER_HEIGHT = 28,
    HINT_GAP = 8,
    HINT_HEIGHT = 58,
    PAGE_JUMP = 8,
    FADE_TIME = 0.14,
    HIGHLIGHT_SPEED = 22,
}

Config.UI = {
    OVERLAY_WIDTH = 300,
    OVERLAY_MARGIN = 20,
    STATUS_LIFETIME = 6,
    MAX_INPUT_LENGTH = 48,
}

Config.SCALES = {
    { label = "Small", value = 0.85 },
    { label = "Normal", value = 1.0 },
    { label = "Large", value = 1.15 },
    { label = "Huge", value = 1.3 },
}

return Config
