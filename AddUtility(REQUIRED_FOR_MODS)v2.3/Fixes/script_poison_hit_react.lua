-- =================================================================================================
-- Author: Fix for poison death animation issue
-- Purpose: Fix poison death animations by making poison use burning hit reactions
-- =================================================================================================

local MOD_NAME = "PoisonHitReactFix"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    -- Fix status effects to use burning_hit for poison damage
    if path == "lua/status_effects/status_effects" and result then        
        local original_poisoned_update = result.poisoned.update_master
        
        -- Override poison update to use burning_hit instead of poison_hit
        result.poisoned.update_master = function(unit, data, dt)
            if data.damage_timer then
                data.damage_timer = data.damage_timer - dt

                if data.damage_timer <= 0 then
                    data.damage_timer = data.interval

                    -- Use burning_hit instead of poison_hit for proper death animation
                    local hit = result.build_damage_hit(unit, "poison", data.damage_per_interval, "burning_hit", data.settings_path, data.ability_name, data.stat_creditor_go_id)
                    result.AbilityEventAux.send_status_effect_hit(hit, result.StatusEffectsLookup[result.poisoned.name])
                end
            end

            if data.time_to_exit == nil then
                return false
            end

            return _G.GAME_TIME >= data.time_to_exit
        end
    end

    -- Alternative approach: Fix gore effect settings for poison
    if path == "lua/settings/gore_effect_settings" and result then        
        if result.burning and result.burning.default then
            result.poison = {
                default = {
                    audio = result.burning.default.audio or "hit_slash_flesh",
                    blood_effect = result.burning.default.blood_effect or "blood_burning",
                    effect_unit_path = result.burning.default.effect_unit_path or "blood_burning",
                    particle = result.burning.default.particle or "effects/hit_slash_burning",
                }
            }
        end
    end

    -- Add poison_hit reactions to hit react files that are missing them
    if string.match(path, "characters/hit_reacts_") and result then        
        if not result.poison_hit and result.burning_hit then
            result.poison_hit = {}
            -- Deep copy burning_hit to poison_hit
            for key, value in pairs(result.burning_hit) do
                if type(value) == "table" then
                    result.poison_hit[key] = {}
                    for subkey, subvalue in pairs(value) do
                        result.poison_hit[key][subkey] = subvalue
                    end
                else
                    result.poison_hit[key] = value
                end
            end
        end
    end

    return result
end)