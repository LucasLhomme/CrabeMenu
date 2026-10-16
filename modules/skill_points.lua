local Loader = ...
local State = Loader.load("core.state")
local Native = Loader.load("core.native")

local SkillPoints = {}

local BASE_TOTAL = 75
local PATCH_PATH = "mods/crabemenu/skilltrees/SkillPointsEarned.patch"
local PATCH_HEADER = "-- Written by CrabeMenu from Settings: raises the skill points a level 20 hero earns. Empty at the default total.\n"

SkillPoints.TOTALS = { BASE_TOTAL, 100, 150, 200 }

--- Returns the skill point total a level 20 hero earns, as chosen for the next launch.
function SkillPoints.getTotal()
    return State.skillPointTotal or BASE_TOTAL
end

--- Returns the index of the chosen total in SkillPoints.TOTALS.
function SkillPoints.getIndex()
    for index, total in ipairs(SkillPoints.TOTALS) do
        if total == SkillPoints.getTotal() then return index end
    end
    return 1
end

--- Chooses the total for the next launch; the game reads its level table once, at startup.
function SkillPoints.setIndex(index)
    State.skillPointTotal = SkillPoints.TOTALS[index]
    if not SkillPoints.writePatch() then return end
    State.setStatus(string.format("Skill points at level 20: %d, applied the next time the game starts",
        State.skillPointTotal), "info")
end

--- Writes the chunk patch CrabeLoader reads at startup, before the game loads its level table.
--- At the default total the patch holds only a comment, so an untouched install keeps the game's own table.
function SkillPoints.writePatch()
    local extra = math.max(0, SkillPoints.getTotal() - BASE_TOTAL)
    local body = PATCH_HEADER
    if extra > 0 then
        body = body .. string.format([[
if Data and Data.AvatarLevels and Data.SkillPointsEarned and not Data.CrabeSkillBonus then
    local points = Data.SkillPointsEarned
    points[#points] = points[#points] + %d
    Data.CrabeSkillBonus = true
end
]], extra)
    end

    local file = io.open(PATCH_PATH, "w")
    if not file then return Native.fail("Skill points: " .. PATCH_PATH .. " cannot be written") end
    file:write(body)
    file:close()
    return true
end

--- Keeps the patch file in step with the saved total at every start.
function SkillPoints.install()
    return SkillPoints.writePatch()
end

return SkillPoints
