-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Fixes issue where carried elemental doesn't properly notify the carrier to exit carry animation state
-- =================================================================================================

local MOD_NAME = "FixCarryAnimation"

local function fix_carrier_animation_for_unit(unit)
    local carryable_state = EntityAux.state_master(unit, "carryable")
    if not carryable_state or not carryable_state.carrier then
        return
    end

    local carrier_unit = carryable_state.carrier
    if not Unit.alive(carrier_unit) then
        return
    end

    Unit.set_data(unit, "exploded", true)

    local avatar_state = EntityAux.state_master(carrier_unit, "avatar")
    if avatar_state then
        if avatar_state.force_animation_busy_mixer then
            avatar_state.force_animation_busy_mixer:remove("carry")
        end
        if avatar_state.carrying then
            avatar_state.carrying = false
        end
    end

    EntityAux.queue_command_master(carrier_unit, "motion", "enable", "carrier") -- Re-enable motion immediately
    EntityAux.queue_command_master(carrier_unit, "rotation", "enable", "carrier") -- Re-enable rotation immediately
    
    EntityAux.queue_command_master(carrier_unit, "animation", "trigger_event", "move") -- Reset to idle/move animation immediately
    
    EntityAux.queue_command_master(carrier_unit, "interactor", "enable") -- Re-enable interactor so player can pick things up again
    
    EntityAux.queue_command_master(carrier_unit, "carrier", "exit_carry") -- Force the carrier component to exit carrying state
end

-- List of elemental orb paths to hook
local elemental_paths = {
    "gameobjects/carry/elemental_ice",
    "gameobjects/carry/elemental_heal",
    "gameobjects/carry/elemental_haste",
    "gameobjects/carry/elemental_poison",
    "gameobjects/carry/elemental_shockwave",
}

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    for _, elemental_path in ipairs(elemental_paths) do
        if path == elemental_path and result then
            local original_on_death = result.on_death_authorative
            result.on_death_authorative = function(unit, is_local_hit, hit, component)
                fix_carrier_animation_for_unit(unit)
                
                if original_on_death then
                    return original_on_death(unit, is_local_hit, hit, component)
                end
            end
        end
    end

    return result
end)
