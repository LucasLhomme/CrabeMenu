local root, env = ...

local Loader = {}
local cache = {}
local compile = loadstring or load

--- Loads a module once per generation, from disk, inside the mod's own environment.
--- Dots and slashes both separate path segments ("core.state" or "core/state").
function Loader.load(name)
    local path = name:gsub("%.", "/") .. ".lua"

    local cached = cache[path]
    if cached ~= nil then return cached end

    local file = io.open(root .. path, "r")
    if not file then
        error(string.format("[CrabeMenu.Loader] module '%s' not found under '%s'", name, root), 2)
    end
    local source = file:read("*a")
    file:close()

    local chunk, compileError = compile(source, "@" .. root .. path)
    if not chunk then
        error("[CrabeMenu.Loader] " .. tostring(compileError), 2)
    end
    setfenv(chunk, env)

    local module = chunk(Loader)
    if module == nil then
        error(string.format("[CrabeMenu.Loader] module '%s' returned nothing", name), 2)
    end

    cache[path] = module
    return module
end

--- Reports whether a module file ships with this copy of the mod. Optional parts
--- (multiplayer, free camera) are kept out of the repository and may be absent.
function Loader.exists(name)
    local file = io.open(root .. name:gsub("%.", "/") .. ".lua", "r")
    if not file then return false end
    file:close()
    return true
end

return Loader
