local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local PlayerModule = {}

local MAX_LEVEL = 20
local ROSTER_LIFETIME = 2
local LIVE_INFO_INTERVAL = 30

PlayerModule.FRANCHISES = {
    { key = "starwars", title = "Star Wars" },
    { key = "marvel", title = "Marvel" },
    { key = "disney", title = "Disney & Pixar" },
    { key = "custom", title = "Custom Heroes" },
}

local roster = nil
local rosterStamp = 0
local liveTicks = 0

local function byName(a, b)
    return tostring(a.name) < tostring(b.name)
end

--- Returns the franchises that have heroes, each with its character list.
--- The result is rebuilt at most every ROSTER_LIFETIME seconds so modded heroes appear.
function PlayerModule.getRoster()
    if roster and State.gameClock - rosterStamp < ROSTER_LIFETIME then return roster end

    roster = {}
    for _, franchise in ipairs(PlayerModule.FRANCHISES) do
        local characters = Native.poll(Game.ListCharacters, franchise.key)
        if characters and #characters > 0 then
            if franchise.key == "custom" then table.sort(characters, byName) end
            roster[#roster + 1] = { title = franchise.title, characters = characters }
        end
    end
    rosterStamp = State.gameClock
    return roster
end

--- Swaps the played character to a SKU using the route chosen in State.applyRoute.
function PlayerModule.swapCharacter(sku, name)
    local before = Native.poll(Game.GetAvatarSku)
    if not Native.run("Game.SetCharacter", Game.SetCharacter, sku, State.applyRoute) then return false end

    State.avatarSku = tonumber(sku) or State.avatarSku
    State.avatarName = name
    State.setStatus(string.format("Swapped to %s (SKU %s -> %s)", name, tostring(before or "?"), tostring(sku)), "success")
    return true
end

--- Raises the avatar level by one.
function PlayerModule.levelUp()
    local before = Native.poll(Game.GetAvatarLevel)
    if not Native.run("Game.LevelUpAvatar", Game.LevelUpAvatar) then return false end

    local after = Native.poll(Game.GetAvatarLevel)
    State.setStatus(string.format("Level up: %s -> %s", tostring(before or "?"), tostring(after or "?")), "success")
    return true
end

--- Sets the avatar progression to the maximum level.
function PlayerModule.maxProgression()
    if not Native.run("Game.SetAvatarProgression", Game.SetAvatarProgression, MAX_LEVEL) then return false end
    State.setStatus("Progression set to level " .. MAX_LEVEL, "success")
    return true
end

--- Adds Sparks to the host player's balance.
function PlayerModule.addSparks(amount)
    if not Native.run("Game.AddToInventory", Game.AddToInventory, "Items.money", amount) then return false end

    local balance = Native.poll(Game.GetSparks)
    State.setStatus(string.format("+%d Sparks (balance: %s)", amount, tostring(balance or "unknown")), "success")
    return true
end

local function nameForSku(sku)
    for _, hero in ipairs(Native.poll(Game.ListCharacters) or {}) do
        if tonumber(hero.sku) == sku then return hero.name end
    end
    return nil
end

--- Refreshes the cached avatar identity every LIVE_INFO_INTERVAL ticks.
--- GetPlayerAvatarData is never polled here: with no avatar loaded (title screen)
--- it dereferences a null pointer and crashes the game, which pcall cannot catch.
function PlayerModule.updateLiveInfo()
    liveTicks = liveTicks + 1
    if liveTicks % LIVE_INFO_INTERVAL ~= 0 then return end

    local sku = Native.poll(Game.GetAvatarSku)
    if not sku or sku == State.avatarSku then return end

    State.avatarSku = sku
    State.avatarName = nameForSku(sku) or State.avatarName
end

return PlayerModule
