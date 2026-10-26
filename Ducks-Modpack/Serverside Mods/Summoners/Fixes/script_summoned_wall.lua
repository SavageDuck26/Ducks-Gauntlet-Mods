
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Restores the Grunt Shaman's cut wall attack"


local MOD_NAME, log_message = Mods.init_mod()

SummonedWall = SummonedWall or {}

-- The wall entity outlived the attack it belonged to: it is still in the generated unit paths and
-- still has its settings, components (dynamic_blocker, damage_receiver, ability, faction) and
-- network object, so putting the attack back is only a matter of spawning it.
SummonedWall.UNIT_PATH = "characters/grunt_shaman/abilities/summoned_wall"

-- The wall is a nav-grid blocker sized from its own unit box, so raising it on the caster would
-- block the cell the shaman is standing in and strand it. Raise it a step ahead instead.
local RAISE_DISTANCE = 3

-- Engine positions are untrusted: world_position and the nav-grid sweeps hand back INF/NaN instead
-- of failing, and a non-finite position passed to EntitySpawner spins the engine (looks like a
-- freeze). NaN fails x == x, INF fails the magnitude bound, so this one check covers both.
local function is_finite(position)
    if position.x ~= position.x or position.y ~= position.y or position.z ~= position.z then
        return false
    end

    return math.abs(position.x) < 100000 and math.abs(position.y) < 100000 and math.abs(position.z) < 100000
end

-- Raises a wall ahead of the caster, facing the way the caster faces. offset_position sweeps the
-- offset, so the wall stops short of real geometry instead of being placed inside it.
function SummonedWall.raise(unit)
    local entity_spawner = FlowCallbacks.state_game.entity_spawner
    local rotation = Unit.world_rotation(unit, 0)
    local position = Unit.world_position(unit, 0)
    local swept = QueryManager:offset_position(position, UnitAux.unit_forward(unit) * RAISE_DISTANCE)

    if swept then
        position = swept
    end

    if not is_finite(position) then
        return
    end

    -- The wall has no motion/static_pose component, so its transform only reaches the other players
    -- through NetworkUnitSynchronizer (FlowCallbacks.spawn_entity does the same for such entities).
    -- add(nil) is a hard "table index is nil" crash during scene update, so check the spawn result.
    local wall = entity_spawner:spawn_entity(SummonedWall.UNIT_PATH, position, rotation)

    if wall then
        NetworkUnitSynchronizer:add(wall)
    end
end
