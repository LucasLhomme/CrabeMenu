local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local Animations = {}

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

local loaded = false

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
    Animations.itemsByCategory = buckets
end

local function ensureLoaded()
    if loaded then return end
    loaded = true
    if not Animations.isAvailable() then return end
    bucketize(Native.poll(Game.ListChoreographies) or {})
end

--- Reports whether the loader ships the choreography catalog (Game.ListChoreographies).
function Animations.isAvailable()
    return type(Game.ListChoreographies) == "function"
end

--- Returns the items of one category, sorting the catalog into categories on first use.
function Animations.getCategory(categoryId)
    ensureLoaded()
    return Animations.itemsByCategory[categoryId]
end

--- Returns how many choreographies the catalog lists.
function Animations.count()
    local all = Animations.getCategory("all")
    return all and #all or 0
end

--- Plays a choreography on the host player.
function Animations.play(name)
    if name == "" then
        State.setStatus("Pick or type an animation name first", "warning")
        return false
    end

    local ok
    if type(Game.PlayChoreography) == "function" then
        ok = Native.run("Game.PlayChoreography", Game.PlayChoreography, name)
    elseif type(PlayAwardCho) == "function" then
        ok = Native.run("PlayAwardCho", PlayAwardCho, Crabe.hostPlayer(), name)
    else
        return Native.fail("Animations: PlayAwardCho is not available in this Lua state")
    end
    if not ok then return false end

    State.setStatus("Playing animation: " .. name, "success")
    return true
end

return Animations
