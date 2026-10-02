local compile = loadstring or load
local env = getfenv(1)

local function scriptDirectory()
    if not (debug and debug.getinfo) then return nil end
    local info = debug.getinfo(1, "S")
    local source = info and info.source
    if not source or source:sub(1, 1) ~= "@" then return nil end

    local normalized = source:sub(2):gsub("\\", "/")
    return normalized:match("^(.*)/[^/]*$")
end

local function loadLoader()
    local roots = { "mods/crabemenu/" }
    local directory = scriptDirectory()
    if directory then table.insert(roots, 1, directory .. "/") end

    for _, root in ipairs(roots) do
        local path = root .. "core/loader.lua"
        local file = io.open(path, "r")
        if file then
            local source = file:read("*a")
            file:close()

            local chunk = assert(compile(source, "@" .. path))
            setfenv(chunk, env)
            return chunk(root, env)
        end
    end
    error("CrabeMenu: core/loader.lua not found in " .. table.concat(roots, ", "), 0)
end

local Loader = loadLoader()

local Config = Loader.load("core.config")
local State = Loader.load("core.state")
local Overlay = Loader.load("ui.overlay")
local Menu = Loader.load("ui.menu")
local Cheats = Loader.load("modules.cheats")
local PlayerModule = Loader.load("modules.player")

local FALLBACK_FRAME_TIME = 0.016

local previouslyDown = {}

local function risingEdge(virtualKey)
    local down = Crabe._keyDown(virtualKey) == 1
    local pressed = down and not previouslyDown[virtualKey]
    previouslyDown[virtualKey] = down
    return pressed
end

local function pollKeys()
    if risingEdge(Config.KEYS.MENU_TOGGLE) then State.setMenuOpen(not State.isMenuOpen) end
    if risingEdge(Config.KEYS.OVERLAY_TOGGLE) then State.toggleOverlay() end
end

Crabe.Mod.register({
    id = "crabemenu",
    name = Config.NAME,
    version = Config.VERSION,

    onInit = function()
        Crabe.write(string.format("[CrabeMenu] v%s ready (F5: menu, F6: overlay)", Config.VERSION))
    end,

    onUpdate = function(dt)
        dt = dt or FALLBACK_FRAME_TIME
        State.gameClock = State.gameClock + dt
        pollKeys()
        Cheats.onTick()
        Overlay.update(dt)
        if State.isMenuOpen or State.isOverlayOpen then PlayerModule.updateLiveInfo() end
    end,

    onDraw = function()
        if State.isMenuOpen then Menu.render() end
        if State.isOverlayOpen then Overlay.render() end
    end,

    onShutdown = function()
        State.setMenuOpen(false)
        State.isOverlayOpen = false
    end,
})
