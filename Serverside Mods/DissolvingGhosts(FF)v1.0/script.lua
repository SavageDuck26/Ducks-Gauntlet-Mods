-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.0
-- Purpose: Makes Ghosts die after 12-15 seconds
-- =================================================================================================

local MOD_NAME = "DissolvingGhosts"

print("[" .. MOD_NAME .. "] Loaded.")

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/ghost/ghost" and result then 
        result.on_entity_registered = function (unit)
        if EntityAux.owned(unit) then
            local command = {
                ability_name = "idle",
            }

            EntityAux.queue_command_master(unit, "ability", "execute_ability", command)
        end
        EntityEventModifierManager:register_modifier(unit, "on_hit_dealt", "ghost", result.on_hit)
        local time_in_seconds = 12 + math.random() * 3
        Game.scheduler:delay_action(time_in_seconds, function ()
            if Unit.alive(unit) then
                EntityAux.call_interface(unit, "i_hit_receiver", "hit", {
                    damage_amount = 99999,
                    settings = {
                        hit_react = "push",
                    },
                    modifiers = {},
                    direction = Vector3Aux.box_temp(-UnitAux.unit_forward(unit)),
                    position = Vector3Aux.box_temp(Unit.world_position(unit, 0)),
                    random_seed = math.random() * 1000,
                })
            end
        end)
        end
    end
    return result
end)