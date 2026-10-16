local Loader = ...
local StateGuard = Loader.load("modules.state_guard")

return StateGuard.new({
    label = "Stealth",
    modes = {
        { label = "Enemies ignore you", state = "NotEnemyPerceivable" },
    },
})
