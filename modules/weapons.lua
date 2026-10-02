local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local Weapons = {}

--- Returns the loader's weapon catalog as ordered { title, items } groups.
function Weapons.getGroups()
    local groups = {}
    if type(Game.ListWeaponCategories) ~= "function" then return groups end

    for _, category in ipairs(Game.ListWeaponCategories()) do
        groups[#groups + 1] = {
            title = category:sub(1, 1):upper() .. category:sub(2),
            items = Game.GetWeaponsInCategory(category),
        }
    end
    return groups
end

--- Equips a tool or weapon on the active avatar.
function Weapons.equip(item)
    if not Native.run("Game.SetActiveTool", Game.SetActiveTool, item.id) then return false end
    State.setStatus("Equipped: " .. item.label, "success")
    return true
end

--- Holsters the current tool.
function Weapons.unequip()
    if not Native.run("Game.UnequipTool", Game.UnequipTool) then return false end
    State.setStatus("Tool holstered", "info")
    return true
end

return Weapons
