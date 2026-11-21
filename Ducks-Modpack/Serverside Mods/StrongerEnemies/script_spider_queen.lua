local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Adds new abilities to the Spider Queen"

local MOD_NAME, log_message = Mods.init_mod()

-- Spin Web and Lay Eggs each get their own checkbox and chance in the mod UI
-- (StrongerEnemies.ABILITY_OPTIONS.spider_queen); both top the cast with a poison projectile.
local function cast_gas_projectile(event)
    local caster_unit = event.caster_unit

    -- Multiplayer safety: validate caster exists and is alive
    if not caster_unit or not Unit.alive(caster_unit) then
        return
    end

    if not EntityAux.owned(caster_unit) then
        return
    end

    -- The engine's aim math can spin forever on a NaN direction, and a caster with no finite position
    -- is one way to feed it one. No position, no cast.
    if not StrongerEnemies.is_finite_position(Unit.world_position(caster_unit, 0)) then
        StrongerEnemies.trace_skip("gas_projectile", caster_unit, "caster position not finite")

        return
    end

    -- The command is queued, so the boxed target must be copied out now; an unboxed engine vector
    -- is a recycled scratch buffer and reads back as nonsense when the ability finally runs.
    local target_pos = StrongerEnemies.event_target_position(event)

    local command = TempTableFactory:get_map(
        "ability_name", "gas_projectile",
        "settings_path", "gameobjects/spawners/spawner_poison_launcher",
        "target_position", target_pos
    )

    EntityAux.queue_command_master(caster_unit, "ability", "execute_ability", command)
end

Mods.hook:set_object(_G, "require", function (orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/spider_queen/spider_queen" and result and _G.is_host_ducks_mods then
        if result.abilities.spin_web.events[1] then
            result.abilities.spin_web.events[1].on_enter_custom = function (ability_event_handler, event)
                if StrongerEnemies.roll_ability("spider_queen", "spin_web") then
                    cast_gas_projectile(event)
                end
            end
        end

        if result.abilities.lay_eggs.events[1] then
            result.abilities.lay_eggs.events[1].on_enter_custom = function (ability_event_handler, event)
                if StrongerEnemies.roll_ability("spider_queen", "lay_eggs") then
                    cast_gas_projectile(event)
                end
            end
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)
