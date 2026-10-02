local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")
local Util = Loader.load("core.util")

local Animations = {}

local CHOREOGRAPHY_DIR = "assets\\choreographies"
local IGNORED_DIRECTORIES = { igp = true, karting = true, psx = true, tcw = true, tron = true, vehicles = true }
local MIN_NAME_LENGTH = 3

Animations.CATEGORIES = {
    { id = "avatar", label = "Universal Avatar" },
    { id = "combos", label = "Combos & Attacks" },
    { id = "specials", label = "Specials & Heroes" },
    { id = "celebrations", label = "Celebrations & Emotes" },
    { id = "cinematics", label = "Cinematics & Scenes" },
    { id = "weapons_vfx", label = "Weapons & VFX" },
    { id = "all", label = "All Choreographies" },
}

local CATEGORY_RULES = {
    { category = "avatar", patterns = { "^ava_", "^nva_" } },
    { category = "combos", patterns = { "combo", "punch", "slash", "strike" } },
    { category = "specials", patterns = { "special", "_prem_", "super", "spawn", "^elsa_", "^nemo_" } },
    { category = "celebrations", patterns = { "hofh_", "_celeb", "victory", "dance", "k3po", "emote" } },
    { category = "cinematics", patterns = { "^cin_", "_cin_", "intro", "scene" } },
    { category = "weapons_vfx", patterns = { "^wpnfx_", "lightsaber", "swoosh", "projectile", "laser" } },
}

local LABEL_PREFIXES = {
    { pattern = "^buzz_", label = "Buzz" },
    { pattern = "^elsa", label = "Elsa" },
    { pattern = "^hulkbuster_", label = "Hulkbuster" },
    { pattern = "^jack_", label = "Jack" },
    { pattern = "^nemo_", label = "Nemo" },
    { pattern = "^ava_", label = "Avatar" },
    { pattern = "^nva_", label = "Avatar" },
    { pattern = "^rr_hofh_", label = "Celebration" },
    { pattern = "^cin_", label = "Cinematic" },
    { pattern = "^wpnfx_", label = "Weapon" },
}

local STRIPPED_PREFIXES = {
    "^buzz_prem_atk_combo_", "^buzz_prem_atk_", "^buzz_prem_",
    "^elsa_prem_ground_", "^elsa_prem_air_", "^elsa_prem_",
    "^hulkbuster_prem_atk_combo_", "^hulkbuster_prem_atk_air_", "^hulkbuster_prem_",
    "^jack_prem_atk_combo_", "^jack_prem_",
    "^nemo_air_combo_", "^nemo_combo_", "^nemo_",
    "^ava_combo", "^nva_combo", "^rr_hofh_",
    "^cin_mba_", "^cin_tcw_", "^cin_", "^wpnfx_",
}

local scanned = false
local filterItems = Util.newFilter({ "id", "label" })

Animations.itemsByCategory = {}

local function labelFor(id)
    local clean = id
    for _, prefix in ipairs(STRIPPED_PREFIXES) do
        local stripped, matches = clean:gsub(prefix, "")
        if matches > 0 then
            clean = stripped
            break
        end
    end

    clean = clean:gsub("_", " "):gsub("^%s*(.-)%s*$", "%1")
    if clean == "" then clean = id end
    clean = clean:sub(1, 1):upper() .. clean:sub(2)

    for _, entry in ipairs(LABEL_PREFIXES) do
        if id:find(entry.pattern) then return entry.label .. ": " .. clean end
    end
    return clean
end

local function categoryFor(id)
    local lowered = id:lower()
    for _, rule in ipairs(CATEGORY_RULES) do
        for _, pattern in ipairs(rule.patterns) do
            if lowered:find(pattern) then return rule.category end
        end
    end
    return nil
end

local function bucketize(ids)
    local buckets = {}
    for _, category in ipairs(Animations.CATEGORIES) do buckets[category.id] = {} end

    for _, id in ipairs(ids) do
        local item = { id = id, label = labelFor(id) }
        buckets.all[#buckets.all + 1] = item
        local category = categoryFor(id)
        if category then buckets[category][#buckets[category] + 1] = item end
    end

    for _, items in pairs(buckets) do
        table.sort(items, function(a, b) return a.id < b.id end)
    end
    Animations.itemsByCategory = buckets
end

local function listLines(command)
    local pipe = io.popen(command)
    if not pipe then return nil end

    local lines = {}
    for line in pipe:lines() do
        lines[#lines + 1] = line:gsub("%s+$", "")
    end
    pipe:close()
    return lines
end

local function collectIds()
    local seen, ids = {}, {}
    local function add(id)
        if id ~= "" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    local directories = listLines('dir /ad /b "' .. CHOREOGRAPHY_DIR .. '" 2>nul')
    if not directories then return nil end
    for _, name in ipairs(directories) do
        if #name >= MIN_NAME_LENGTH and not IGNORED_DIRECTORIES[name:lower()] then add(name) end
    end

    local archives = listLines('dir /s /b "' .. CHOREOGRAPHY_DIR .. '\\*.zip" 2>nul') or {}
    for _, path in ipairs(archives) do
        add(path:match("([^\\/]+)%.zip$") or "")
    end

    table.sort(ids)
    return ids
end

--- Scans assets/choreographies for animation names and sorts them into categories.
function Animations.scan()
    scanned = true
    Animations.itemsByCategory = {}
    if not io.popen then return Native.fail("Animations: io.popen is unavailable, cannot scan the game folder") end

    local ok, ids = Native.run("Animations scan", collectIds)
    if not ok then return false end
    if not ids then return Native.fail("Animations: could not list " .. CHOREOGRAPHY_DIR) end
    if #ids == 0 then
        State.setStatus("No choreographies found under " .. CHOREOGRAPHY_DIR, "warning")
        return false
    end

    bucketize(ids)
    State.setStatus(string.format("Found %d choreographies", #ids), "success")
    return true
end

--- Reports whether a scan has been attempted since the module was loaded.
function Animations.hasScanned()
    return scanned
end

--- Returns the items of a category whose id or label matches the search text.
function Animations.getItems(categoryId, searchText)
    local items = Animations.itemsByCategory[categoryId] or {}
    return filterItems(items, searchText)
end

--- Plays a choreography on the host player.
function Animations.play(name)
    if name == "" then
        State.setStatus("Pick or type an animation name first", "warning")
        return false
    end
    if type(PlayAwardCho) ~= "function" then
        return Native.fail("Animations: PlayAwardCho is not available in this Lua state")
    end
    if not Native.run("PlayAwardCho", PlayAwardCho, name, Crabe.hostPlayer()) then return false end

    State.setStatus("Playing animation: " .. name, "success")
    return true
end

return Animations
