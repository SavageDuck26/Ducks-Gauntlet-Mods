-- =================================================================================================
-- Author: SavageDuck26 (modified)
-- Purpose: Modifies Cultist Zealot to spawn a Demon Melee on death
-- =================================================================================================

local MOD_NAME = "SummonerCultistZealot"

-- Helper function to check if cultist_zealot summoning is enabled
local function is_cultist_zealot_enabled()
    if Summoners.CONFIG.enabled == false then
        return false
    end
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.cultist_zealot then
        return Summoners.CONFIG.summoners.cultist_zealot.enabled
    end
    return true
end

-- Helper function to get spawn chance
local function get_death_spawn_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.cultist_zealot then
        return Summoners.CONFIG.summoners.cultist_zealot.death_spawn_chance or 1.00
    end
    return 1.00
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/cultist_zealot/cultist_zealot" and result and _G.is_host_ducks_mods == true then

        if result.abilities.on_death then
            if result.abilities.on_death.on_exit then
                local original_on_exit = result.abilities.on_death.on_exit.custom_callback
                result.abilities.on_death.on_exit.custom_callback = function(component, unit, ability)
                    -- Call original on_exit if it exists
                    if original_on_exit then
                        original_on_exit(component, unit, ability)
                    end
                    
                    if not is_cultist_zealot_enabled() then return end
                    if math.random() > get_death_spawn_chance() then return end
                    
                    local entity_spawner = FlowCallbacks.state_game.entity_spawner
                    local position = Unit.world_position(unit, 0)
                    local rotation = Unit.world_rotation(unit, 0)
                    
                    local spawn = entity_spawner:spawn_entity("demon_melee", position, rotation)
                    NetworkUnitSynchronizer:add(spawn)
                end
            end
        end
    end
    return result
end)