
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds new abilities to the Bloated Mummy (Like Dark Legacy)"

local MOD_NAME, log_message = Mods.init_mod()


-- Per-bomber roll chances; overridable from the mod UI.
local function acid_bomber_chance()
    return StrongerEnemies.get_chance("mummy_bloated", "acid_bomber_chance", 0.10)
end

local function ice_bomber_chance()
    return StrongerEnemies.get_chance("mummy_bloated", "ice_bomber_chance", 0.10)
end

local function fire_bomber_chance()
    return StrongerEnemies.get_chance("mummy_bloated", "fire_bomber_chance", 0.10)
end
-- ===========================================================================
local function is_acid_bomber(unit)
    if math.random() < acid_bomber_chance() then
        return true
    end
    
    return false
end
local acid_bomber_status = {
    poisoned = {
        damage_per_interval = 0,
        duration = 1000,
        interval = 1,
    },
}
-- ===========================================================================
local function is_ice_bomber(unit)
    if math.random() < ice_bomber_chance() then
        return true
    end

    return false
end
local ice_bomber_status = {
    chilled = {
        duration = 1000,
        speed_modifier = 0,
    },
}
-- ===========================================================================
-- The fire bomber keeps the mummy's own death explosion and adds a burn to it.
local BURN_DAMAGE_PER_SECOND = 4
local BURN_DURATION = 5
local function is_fire_bomber(unit)
    if math.random() < fire_bomber_chance() then
        return true
    end

    return false
end
local fire_bomber_status = {
    burning = {
        damage_per_second = 0,
        duration = 1000,
        interval = 1,
    },
}
-- ===========================================================================
-- The acid and ice bombers replace the mummy's blast with a carry-and-explode elemental; the fire
-- bomber keeps the blast (see the on_death hook) and just adds a burn to it.
local ELEMENTALS = {
    is_acid_bomber = "gameobjects/carry/elemental_poison",
    is_ice_bomber = "gameobjects/carry/elemental_ice",
}

local function explode_elemental(ability_event_handler, event, unit_path)
    local caster_unit = event.caster_unit
    local stat_creditor_go_id = event.stat_creditor_go_id

    local spawned = ability_event_handler.entity_spawner:spawn_entity(unit_path, Unit.world_position(caster_unit, 0), Unit.world_rotation(caster_unit, 0), nil, {
        stat_creditor_go_id = stat_creditor_go_id,
    })

    if spawned then
        EntityAux.queue_command_master(spawned, "ability", "execute_ability", {
            ability_name = "explode",
            stat_creditor_go_id = stat_creditor_go_id,
        })
    end
end

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/mummy_bloated/mummy_bloated" and result and _G.is_host_ducks_mods then

        result.on_entity_registered = function(unit)
            local acid_bomber = false
            local ice_bomber = false
            local fire_bomber = false

            if StrongerEnemies.is_enabled("mummy_bloated") and EntityAux.owned(unit) then
                -- Independent rolls, so a mummy can be any combination of bombers at once.
                acid_bomber = is_acid_bomber(unit)
                ice_bomber = is_ice_bomber(unit)
                fire_bomber = is_fire_bomber(unit)
                Unit.set_data(unit, "is_acid_bomber", acid_bomber)
                Unit.set_data(unit, "is_ice_bomber", ice_bomber)
                Unit.set_data(unit, "is_fire_bomber", fire_bomber)
            end

            if acid_bomber or ice_bomber or fire_bomber then
                if EntityAux.is_alive_entity(unit) then
                    if acid_bomber then
                        EntityAux.call_master(unit, "status_receiver", "add_status_effect", acid_bomber_status)
                    end

                    if ice_bomber then
                        EntityAux.call_master(unit, "status_receiver", "add_status_effect", ice_bomber_status)
                    end

                    if fire_bomber then
                        EntityAux.call_master(unit, "status_receiver", "add_status_effect", fire_bomber_status)
                    end
                end
            else
                -- Regular explosion
            end
        end

        if result.abilities.on_death.events[1] then
            result.abilities.on_death.events[1].on_enter_custom = function(ability_event_handler, event)
                local owner = event.owner_unit or event.caster_unit or event.unit
                local acid_bomber = owner and Unit.get_data(owner, "is_acid_bomber")
                local ice_bomber = owner and Unit.get_data(owner, "is_ice_bomber")
                local fire_bomber = owner and Unit.get_data(owner, "is_fire_bomber")

                if not (acid_bomber or ice_bomber or fire_bomber) then
                    -- Regular explosion
                    return
                end

                local caster_unit = event.caster_unit

                -- Multiplayer safety: validate caster exists and is alive
                if not caster_unit or not Unit.alive(caster_unit) then
                    return
                end

                if not EntityAux.owned(caster_unit) then
                    return
                end

                if acid_bomber or ice_bomber then
                    -- Acid / ice drop the mummy's own blast and spawn their carry-and-explode elemental.
                    event.damage_amount = 0

                    if event.settings then
                        event.settings.damage_amount = 0
                    end

                    explode_elemental(ability_event_handler, event, acid_bomber and ELEMENTALS.is_acid_bomber or ELEMENTALS.is_ice_bomber)
                end

                if fire_bomber and event.settings then
                    -- The fire bomber keeps the mummy's explosion and burns whatever it catches.
                    event.settings.status_effects = {
                        burning = {
                            damage_per_second = BURN_DAMAGE_PER_SECOND,
                            duration = BURN_DURATION,
                            interval = 1,
                        },
                    }
                end
            end
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
