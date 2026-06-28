-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Adds spawning abilities to Skeleton Commander
-- =================================================================================================

local MOD_NAME = "SummonerSkeletonCommander"

-- Helper function to check if skeleton_commander summoning is enabled
local function is_skeleton_commander_enabled()
    if Summoners.CONFIG.enabled == false then
        return false
    end
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.skeleton_commander then
        return Summoners.CONFIG.summoners.skeleton_commander.enabled
    end
    return true
end

-- Helper function to get spawn chance
local function get_arrow_lob_chance()
    if Summoners.CONFIG.summoners and Summoners.CONFIG.summoners.skeleton_commander then
        return Summoners.CONFIG.summoners.skeleton_commander.arrow_lob_chance or 1.00
    end
    return 1.00
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/skeleton_commander/skeleton_commander" and result and _G.is_host_ducks_mods == true then
        if result.abilities then
            -- Modify arrow_lob to spawn a lich at the end (conditionally)
            local original_arrow_lob = result.abilities.arrow_lob
            result.abilities.arrow_lob = {
                animation = "attack_lob",
                duration = 100,
                rotation_lock_start = 1,
                flow_events = {
                    {
                        event_name = "on_bow_windup",
                        time = 0,
                    },
                    {
                        event_name = "on_bow_fire",
                        time = 40,
                    },
                },
                spawn_entities = is_skeleton_commander_enabled() and math.random() < get_arrow_lob_chance() and {
                    {
                        spawn_ai_monster = true,
                        spawn_info_key = "default",
                        time = 80,
                        unit_path = "lich",
                        use_target_position = true,
                    },
                } or nil,
                events = {
                    {
                        angle = 30,
                        collision_filter = "floor_only",
                        damage_amount = 0,
                        drag_coefficient = 0,
                        effect_type = "arrow",
                        event_duration = 1,
                        event_start = 40,
                        hit_react = "light",
                        marker_unit_path = "skeleton_commander_spell_marker",
                        speed_multiplier = 0.8,
                        stagger_origin_type = "direction",
                        type = "projectile_lob",
                        unit_path = "skeleton_commander_arrow",
                        origin = {
                            x = 0.2,
                            y = 0.6,
                            z = 1.6,
                        },
                        on_event_complete = {
                            ability = "arrow_explosion",
                        },
                    },
                },
            }
        end
    end

    return result
end)