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
local Keybinds = Loader.load("core.keybinds")
local Input = Loader.load("core.input")
local Settings = Loader.load("core.settings")
local Menu = Loader.load("ui.menu")
local Overlay = Loader.load("ui.overlay")
local SpeedrunHud = Loader.load("ui.speedrun_hud")
local Cheats = Loader.load("modules.cheats")
local PlayerModule = Loader.load("modules.player")
local PlaysetBypass = Loader.load("modules.playset_bypass")
local Speedrun = Loader.load("modules.speedrun")
local SpeedHack = Loader.load("modules.speedhack")
local WorldModule = Loader.load("modules.world")
local SkillPoints = Loader.load("modules.skill_points")
local NoFall = Loader.load("modules.nofall")
local Stealth = Loader.load("modules.stealth")

local FALLBACK_FRAME_TIME = 0.016

local canDraw = type(ImGui) == "table" and type(ImGui.DrawText) == "function"
    and type(ImGui.GetDisplaySize) == "function"

Settings.load()
Keybinds.load()
SkillPoints.install()
PlaysetBypass.init()
Menu.setRoot(Loader.load("ui.pages.main"))

Crabe.Mod.register({
    id = "crabemenu",
    name = Config.NAME,
    version = Config.VERSION,

    onInit = function()
        State.releaseInput()
        if not canDraw then
            Crabe.write("[CrabeMenu] this CrabeLoader has no ImGui.DrawText: update CrabeLoader (deploy.ps1 -Full)")
            return
        end
        Crabe.write(string.format("[CrabeMenu] v%s ready (%s or RB + D-pad left: menu, %s: overlay)", Config.VERSION,
            Keybinds.label("menuToggle"), Keybinds.label("overlayToggle")))
    end,

    onUpdate = function(dt)
        dt = dt or FALLBACK_FRAME_TIME
        State.gameClock = State.gameClock + dt
        if canDraw then Menu.update(dt) end
        if Input.overlayToggled() then
            State.toggleOverlay()
            Settings.save()
        end
        Cheats.onTick()
        Speedrun.onTick(dt)
        WorldModule.onTick()
        SpeedHack.onTick()
        NoFall.onTick()
        Stealth.onTick()
        PlaysetBypass.onTick()
        Overlay.update(dt)
        SpeedrunHud.update(dt)
        if State.isMenuOpen or State.isOverlayOpen then PlayerModule.updateLiveInfo() end
    end,

    onDraw = function()
        if not canDraw then return end
        Menu.render()
        if State.isOverlayOpen then Overlay.render() end
        if State.isSpeedrunHudOpen then SpeedrunHud.render() end
    end,

    onShutdown = function()
        Menu.setOpen(false)
        State.isOverlayOpen = false
    end,
})
