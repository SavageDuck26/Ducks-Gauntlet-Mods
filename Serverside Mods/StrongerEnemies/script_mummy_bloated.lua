-- =================================================================================================
-- Author: SavageDuck26
-- =================================================================================================

local MOD_NAME = "StrongerBloatedMummy"

local function is_acid_bomber(unit)
    if math.random() < 0.10 then
        return true
    else
        return false
    end
end

local acid_bomber_status = {
    poisoned = {
        damage_per_interval = 0,
        duration = 1000,
        interval = 1,
    },
}

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/mummy_bloated/mummy_bloated" and result and _G.is_host_ducks_mods then

        result.on_entity_registered = function(unit)
            local bomber = false

            if EntityAux.owned(unit) then
                bomber = is_acid_bomber(unit)
                Unit.set_data(unit, "is_acid_bomber", bomber)
            end

            if bomber then
                if EntityAux.is_alive_entity(unit) then
                    EntityAux.call_master(unit, "status_receiver", "add_status_effect", acid_bomber_status)
                end
            else
                -- Regular explosion
            end
        end

        if result.abilities.on_death.events[1] then
            result.abilities.on_death.events[1].on_enter_custom = function(ability_event_handler, event)
                local owner = event.owner_unit or event.caster_unit or event.unit
                if owner and Unit.get_data(owner, "is_acid_bomber") then
                    event.damage_amount = 0

                    if event.settings then
                        event.settings.damage_amount = 0
                    end

                    local caster_unit = event.caster_unit
                    
                    -- Multiplayer safety: validate caster exists and is alive
                    if not caster_unit or not Unit.alive(caster_unit) then
                        return
                    end

                    if EntityAux.owned(caster_unit) then
                        local position = Unit.world_position(caster_unit, 0)
                        local rotation = Unit.world_rotation(caster_unit, 0)
                        local stat_creditor_go_id = event.stat_creditor_go_id

                        local spawned = ability_event_handler.entity_spawner:spawn_entity("gameobjects/carry/elemental_poison", position, rotation, nil, {
                            stat_creditor_go_id = stat_creditor_go_id,
                        })

                        if spawned then
                            EntityAux.queue_command_master(spawned, "ability", "execute_ability", {
                                ability_name = "explode",
                                stat_creditor_go_id = stat_creditor_go_id,
                            })
                        else
                            -- Nothin
                        end
                    end
                else
                    -- Regular explosion
                end
            end
        end
    end

    return result
end)
