-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.2
-- Purpose: Replaces ghost enemies with skeletons.
-- =================================================================================================

NoGhosts = NoGhosts or {}
NoGhosts.loaded = true

local MOD_NAME = "NoGhosts"

-- print("[" .. MOD_NAME .. "] Gettings rid of those pesky ghosts...")

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/lich/lich" and result then 
        if result.ability_selection and result then
            result.ability_selection.ghost_swarm = result.ability_selection.raise_skeletons
        end
        if result.abilities and result.abilities.ghost_swarm then
            result.abilities.ghost_swarm = result.abilities.raise_skeletons
        end
    end

    if path == "gameobjects/spawners/spawner_ghost" and result then 
        if result.abilities and result.abilities.spawn_ghost then
            result.abilities.spawn_ghost = {
                duration = 300,
                ignore_interrupt = true,
                flow_events = {
                    {
                        event_name = "on_ghost_spawn",
                        time = 0,
                    },
                },
                spawn_entities = {
                    {
                        random_rotation = true,
                        spawn_ai_monster = true,
                        spawn_info_key = "default",
                        time = 25,
                        unit_path = "characters/skeleton_soldier/skeleton_soldier",
                        random_position_offset = {
                            max_radius = 2,
                            min_radius = 0.5,
                        },
                    },
                    {
                        random_rotation = true,
                        spawn_ai_monster = true,
                        spawn_info_key = "default",
                        time = 28,
                        unit_path = "characters/skeleton_soldier/skeleton_soldier",
                        random_position_offset = {
                            max_radius = 2,
                            min_radius = 0.5,
                        },
                    },
                    {
                        random_rotation = true,
                        spawn_ai_monster = true,
                        spawn_info_key = "default",
                        time = 30,
                        unit_path = "characters/skeleton_soldier/skeleton_soldier",
                        random_position_offset = {
                            max_radius = 2,
                            min_radius = 0.5,
                        },
                    },
                },
            }
        end
    end
    return result
end)