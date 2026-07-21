
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds enemies that drop keys to avoid softlocks in endless"


local MOD_NAME = "KnossosKeybearers"
local KEY_UNIT_PATH = "gameobjects/keys/small"

local TARGET_UNITS = {
    ["characters/mummy_risen/mummy_risen"] = true,
    ["characters/orc_melee/orc_melee"] = true,
    ["characters/cultist_novice/cultist_novice"] = true,
}

local function spawn_dropped_key(position)
    if not position then
        return
    end

    local state_game = FlowCallbacks and FlowCallbacks.state_game
    local entity_spawner = state_game and state_game.entity_spawner

    if not entity_spawner then
        return
    end

    local dropped_unit = entity_spawner:spawn_entity(KEY_UNIT_PATH, position, Quaternion.identity(), nil)

    if not dropped_unit then
        return
    end

    Unit.set_data(dropped_unit, "is_dropped", true)
    Unit.flow_event(dropped_unit, "on_dropped")

    if NetworkUnitSynchronizer and NetworkUnitSynchronizer.add then
        NetworkUnitSynchronizer:add(dropped_unit)
    end
end

Mods.hook:set(MOD_NAME, "require", function (orig, path, ...)
    local result = orig(path, ...)

    if not result or not TARGET_UNITS[path] then
        return result
    end

    Knossos = Knossos or {}
    if not Knossos.enabled then
        return result
    end

    local original_on_death_authorative = result.on_death_authorative

    result.on_death_authorative = function (unit, is_local_hit, hit, component)
        local owned_by_this_peer = EntityAux and EntityAux.owned and EntityAux.owned(unit)
        local death_position = Unit.alive(unit) and Unit.world_position(unit, 0) or nil

        if original_on_death_authorative then
            original_on_death_authorative(unit, is_local_hit, hit, component)
        end

        if owned_by_this_peer then
            if math.random() < 0.97 then
                return
            end
            spawn_dropped_key(death_position)
        end
    end

    return result
end)
