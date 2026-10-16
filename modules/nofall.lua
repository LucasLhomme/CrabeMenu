local Loader = ...
local StateGuard = Loader.load("modules.state_guard")

return StateGuard.new({
    label = "No fall",
    modes = {
        { label = "No reaction", state = "Unkillable" },
        { label = "Flinch only", state = "EnemyUninterruptable" },
    },
})
