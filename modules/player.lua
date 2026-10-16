local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local PlayerModule = {}

local MAX_LEVEL = 20
local MIN_LEVEL = 1
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
            table.sort(characters, byName)
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

--- Lowers the avatar level by one. Experience is kept, so the next experience gained may raise it again.
--- When the skills bought no longer fit the lower level they are refunded, which uses one of the
--- figure's two free respecs.
function PlayerModule.levelDown()
    local level = tonumber(Native.poll(Game.GetAvatarLevel))
    if not level then return Native.fail("Level down: the avatar level cannot be read here") end
    if level <= MIN_LEVEL then
        State.setStatus("Already at level " .. MIN_LEVEL, "warning")
        return false
    end

    local target = level - 1
    local ok, reported = Native.run("Game.SetAvatarLevel", Game.SetAvatarLevel, target)
    if not ok then return false end
    if tonumber(reported) ~= target then
        return Native.fail("Level down: the game reports level " .. tostring(reported) .. " instead of " .. target)
    end

    local refunded = false
    if (tonumber(Native.poll(Game.GetSkillPoints)) or 0) < 0 then
        if not Native.run("Game.RespecAvatar", Game.RespecAvatar) then return false end
        refunded = true
    end

    State.setStatus(string.format("Level down: %d -> %d (skill points: %s)%s", level, target,
        tostring(Native.poll(Game.GetSkillPoints) or "?"), refunded and ", skills refunded" or ""), "success")
    return true
end

--- Sets the hero to the maximum level and reports the level and skill points the game shows afterwards.
function PlayerModule.maxProgression()
    local ok, reported = Native.run("Game.SetAvatarLevel", Game.SetAvatarLevel, MAX_LEVEL)
    if not ok then return false end
    if tonumber(reported) ~= MAX_LEVEL then
        return Native.fail("Max level: the game reports level " .. tostring(reported))
    end
    State.setStatus(string.format("Level %d (skill points: %s)", MAX_LEVEL,
        tostring(Native.poll(Game.GetSkillPoints) or "?")), "success")
    return true
end

--- Adds Sparks to the host player's balance.
function PlayerModule.addSparks(amount)
    if not Native.run("Game.AddToInventory", Game.AddToInventory, "Items.money", amount) then return false end

    local balance = Native.poll(Game.GetSparks)
    State.setStatus(string.format("+%d Sparks (balance: %s)", amount, tostring(balance or "unknown")), "success")
    return true
end

--- Refunds every skill the hero bought, free, so the points can be spent again.
--- The game allows two such refunds per figure; the points shown afterwards come from the game.
function PlayerModule.refundSkillPoints()
    local before = tonumber(Native.poll(Game.GetSkillPoints))
    if not Native.run("Game.RespecAvatar", Game.RespecAvatar) then return false end

    local after = tonumber(Native.poll(Game.GetSkillPoints))
    State.setStatus(string.format("Skill points refunded: %s -> %s", tostring(before or "?"), tostring(after or "?")), "success")
    return true
end

--- Removes Sparks from the host player's balance, never below zero; amount nil removes them all.
--- Reports the balance the game shows afterwards, not the one asked for.
function PlayerModule.removeSparks(amount)
    local before = tonumber(Native.poll(Game.GetSparks))
    if not before then return Native.fail("Sparks: the balance cannot be read here") end

    local removed = math.floor(math.min(amount or before, before))
    if removed <= 0 then
        State.setStatus("You have no Sparks to remove", "warning")
        return false
    end

    if not Native.run("Game.RemoveFromInventory", Game.RemoveFromInventory, "Items.money", removed) then return false end

    local after = tonumber(Native.poll(Game.GetSparks))
    if after == before then return Native.fail("Sparks: the balance did not change (still " .. before .. ")") end
    State.setStatus(string.format("-%d Sparks (balance: %s)", removed, tostring(after or "unknown")), "success")
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
