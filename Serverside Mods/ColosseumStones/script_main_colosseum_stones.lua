-- =================================================================================================
-- Author: SavageDuck26, Hoyt, Skapp, Kryptic (Without Hoyt's code from Bmod, this mod would not be done)
-- Version: 2.0
-- Purpose: Replace normal spawners with colosseum stone spawners
-- =================================================================================================

local MOD_NAME = "ColosseumStones"

ColosseumStones = ColosseumStones or {}
ColosseumStones.loaded = true

-- Saveable settings
ColosseumStones.CONFIG = ColosseumStones.CONFIG or {
    enabled = true,
    replacement_chance = 1,
    harder_stones_enabled = false,
    stone_types = {
        exploding = true,
        freeze_nova = true,
        mortar = true,
        twister = true,
        beam = true,
        poison_launcher = true,
    },
    stone_weights = {
        exploding = 1,
        freeze_nova = 2,
        mortar = 1,
        twister = 3,
        beam = 3,
        poison_launcher = 1,
    },
}

local CLUSTER_RADIUS = 4

local endless_spawners = {
    "spawner_caves_grunt",
    "spawner_caves_grunt_t1", 
    "spawner_caves_orc",
    "spawner_caves_orc_t1",
    "spawner_crypt_mummy",
    "spawner_crypt_mummy_t1",
    "spawner_crypt_skeleton",
    "spawner_crypt_skeleton_t1",
    "spawner_lava_cultist",
    "spawner_lava_cultist_t1",
    "spawner_lava_daemon",
    "spawner_lava_daemon_t1",
    "spawner_ghost"
}

ColosseumStones.spawners = {
    { short_path = "spawner_exploding", weight = 1 },
    { short_path = "spawner_freeze_nova", weight = 2 },
    { short_path = "spawner_mortar", weight = 2 },
    { short_path = "spawner_twister", weight = 3 },
    { short_path = "spawner_beam", weight = 3 },
    { short_path = "spawner_poison_launcher", weight = 1 },
}

local endless_spawners_set = {}
for _, spawner in ipairs(endless_spawners) do
    endless_spawners_set[spawner] = true
end

local function pick_weighted_spawner(list)
    local all_weights = 0
    for _, v in ipairs(list) do
        all_weights = all_weights + (1 / v.weight)
    end
    local random_weight = math.random() * all_weights
    local combined_weight = 0
    for _, v in ipairs(list) do
        combined_weight = combined_weight + (1 / v.weight)
        if random_weight <= combined_weight then return v.short_path end
    end
    return list[#list].short_path
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/managers/procedural_spawning_manager" then

        Mods.hook:set(MOD_NAME, "ProceduralSpawningManager.spawn_at_point",
            function(orig, self, spawn_point, setup_info)  -- Added orig to match other mod's pattern
                
                -- Safety check: Ensure spawn_point and its properties are valid
                if not spawn_point or not spawn_point.group or not spawn_point.group.enemy_infos or type(spawn_point.group.enemy_infos) ~= "table" then
                    return  -- Exit early to prevent crash
                end
                
                local enemy_infos = table.clone(spawn_point.group.enemy_infos)
                local is_spawner = spawn_point.group.is_spawner

                for _, enemy_info in ipairs(enemy_infos) do
                    enemy_info.left_to_spawn = math.interpolate_increasing(enemy_info.max, PlayerManager:num_players())
                end

                local position = Vector3Aux.unbox(spawn_point.position)

                while #enemy_infos > 0 do
                    local index = math.random(#enemy_infos)
                    local random_pick = enemy_infos[index]
                    local remove_me = true

                    if is_spawner or random_pick.is_death then
                        local entity_spawner = FlowCallbacks.state_game.entity_spawner
                        
                        if endless_spawners_set[random_pick.unit_path] then
                            if math.random() <= ColosseumStones.CONFIG.replacement_chance then
                                local random_colosseum_stone = pick_weighted_spawner(ColosseumStones.spawners)
                                
                                -- Inherit enemy info: Get original spawner's settings and apply to setup_info
                                local spawner_wave_selection_orig = setup_info.spawner_wave_selection
                                local spawner_settings = nil
                                if _G.SHORT_PATHS and _G.SHORT_PATHS[random_pick.unit_path] then
                                    local success, settings = pcall(LuaSettingsManager.get_settings_by_settings_path, LuaSettingsManager, _G.SHORT_PATHS[random_pick.unit_path])
                                    if success then
                                        spawner_settings = settings
                                    end
                                end
                                if spawner_settings then
                                    setup_info.spawner_wave_selection = spawner_settings.spawner_wave_selection
                                end
                                
                                entity_spawner:spawn_entity(random_colosseum_stone, position, Quaternion.identity(), nil, setup_info)
                                
                                -- Restore original spawner_wave_selection
                                setup_info.spawner_wave_selection = spawner_wave_selection_orig
                            else
                                entity_spawner:spawn_entity(random_pick.unit_path, position, Quaternion.identity(), nil, setup_info)
                            end
                        else
                            entity_spawner:spawn_entity(random_pick.unit_path, position, Quaternion.identity(), nil, setup_info)
                        end
                    else
                        local adjusted_position = QueryManager:query_position_in_hollow_disc(position, 0, CLUSTER_RADIUS, 0.5)
                        AIManager:spawn_monster(random_pick.unit_path, adjusted_position, Quaternion.identity(), nil, setup_info)
                    end

                    random_pick.left_to_spawn = random_pick.left_to_spawn - 1
                    remove_me = random_pick.left_to_spawn <= 0

                    if remove_me then
                        table.remove(enemy_infos, index)
                    end
                end
            end)
        
    end
    return result
end)