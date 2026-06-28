-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Performance optimization mod - smoother culling, increased limits, FPS unlocking
-- =================================================================================================

local MOD_NAME = "PerformanceChanges"

PerformanceChanges = PerformanceChanges or {}

PerformanceChanges.CONFIG = PerformanceChanges.CONFIG or {
    -- CULLING SETTINGS
    -- "disabled" = no culling at all (all enemies always visible)
    -- "relaxed" = culling happens but at much larger distances and smoother
    -- "default" = use game's default culling (mod does nothing to culling)
    culling = {
        mode = "relaxed",
        
        -- Settings for "relaxed" mode only:
        cull_distance = 50,                 -- Distance at which entities get culled (default: 11)
        uncull_distance = 40,               -- Distance at which entities get unculled (default: 5)
        enemy_cull_multiplier = 3,          -- Enemies cull at this * cull_distance (default: 3)
        fraction_per_frame = 0.20,          -- Fraction of entities checked per frame (default: 0.025)
    },
    
    -- AI and Spawn Settings
    -- Original values: max_monsters = 100, spawns_per_frame = 1
    ai = {
        max_monsters = 300,                 -- Max active monsters (default: 100)
        max_spawns_per_frame = 4,           -- Enemies spawned per frame (default: 1)
        disable_ai_culling = true,          -- Disable AIManager's own culling (_cull_distant)
    },
    
    -- FPS Settings
    fps = {
        unlock_fps = false,                  -- Set to true to remove FPS cap entirely
        target_fps = 60,                   -- Target FPS if unlock_fps is false (default: 60 or 120)
    },
    
    -- Visual Effect and Decals
    visuals = {
        max_decals = 512,                  -- Max blood/effect decals on screen (default: 512)
        decal_fade_time = 1.0,              -- How fast decals fade out in seconds (default: 2.0)
        emissive_fade_time = 3.0,           -- How fast emissive decals fade (default: 5.0)
    },
    
    -- Corpse/Gibs Settings
    gibs = {
        fast_despawn = true,                -- Enable faster corpse cleanup
        despawn_wait_time = 1.0,            -- Seconds before decay starts (default: 2.0)
        decay_duration = 1.5,               -- How long decay animation takes (default: 3.0)
        gib_light_wait = 0.1,               -- Gib static light wait time (default: 0.2)
        gib_light_fade = 0.2,               -- Gib static light fade time (default: 0.4)
    },
}

PerformanceChanges.initialized = false
PerformanceChanges.hooks_applied = {}

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/managers/entity_culling_manager" and not PerformanceChanges.hooks_applied.culling then
        PerformanceChanges.hooks_applied.culling = true
        
        if PerformanceChanges.CONFIG.culling.mode == "disabled" then
            Mods.hook:set(MOD_NAME, "EntityCullingManager.should_cull", function(orig, self)
                return false  -- Never cull
            end)

        elseif PerformanceChanges.CONFIG.culling.mode == "relaxed" then
            Mods.hook:set(MOD_NAME, "EntityCullingManager.register_unit", function(orig, self, unit)
                orig(self, unit)
                
                local data = self.not_culled_units[unit]
                if data then
                    if EntityAux.has_component(unit, "enemy") then
                        data.cull_distance = PerformanceChanges.CONFIG.culling.enemy_cull_multiplier * PerformanceChanges.CONFIG.culling.cull_distance
                    else
                        data.cull_distance = PerformanceChanges.CONFIG.culling.cull_distance
                    end
                end
            end)
            
            Mods.hook:set(MOD_NAME, "EntityCullingManager.update", function(orig, self, dt)
                if dt == 0 then return end
                if not self:should_cull() then return end
                
                local now = _G.GAME_TIME
                local camera = CameraManager:get_camera()
                if not camera then return end
                
                local camera_position = Camera.local_position(camera)
                local last_position = Vector3Aux.unbox(self.camera_position)
                Vector3Aux.box(self.camera_position, camera_position)
                
                local camera_velocity = Vector3.distance_xy(last_position, camera_position) / dt
                local camera_moved_a_lot = camera_velocity > 40
                
                local CULL_DIST = PerformanceChanges.CONFIG.culling.cull_distance
                local UNCULL_DIST = PerformanceChanges.CONFIG.culling.uncull_distance
                local FRACTION = PerformanceChanges.CONFIG.culling.fraction_per_frame
                
                -- CULL PASS
                local not_culled_count = #self.not_culled_units_list
                if not_culled_count > 0 then
                    local checks = math.max(1, math.floor(FRACTION * not_culled_count))
                    local start_idx = self.last_not_culled_index
                    
                    for i = 0, checks - 1 do
                        local idx = ((start_idx - 1 + i) % not_culled_count) + 1
                        local data = self.not_culled_units_list[idx]
                        
                        if data and now >= (data.time_to_consider or 0) then
                            local unit = data.unit
                            if unit and Unit.alive(unit) then
                                local pos = Unit.world_position(unit, 0)
                                local _, dist = CameraManager:is_position_inside_frustum(pos)
                                local cull_dist = data.cull_distance or CULL_DIST
                                
                                if dist >= cull_dist then
                                    self:cull_unit(unit)
                                else
                                    data.time_to_consider = now + 0.3
                                end
                            end
                        end
                    end
                    
                    self.last_not_culled_index = ((self.last_not_culled_index - 1 + checks) % not_culled_count) + 1
                end
                
                local culled_count = #self.culled_units_list
                if culled_count > 0 then
                    if camera_moved_a_lot then
                        for i = 1, culled_count do
                            if self.culled_units_list[i] then
                                self.culled_units_list[i].time_to_consider = 0
                            end
                        end
                    end
                    
                    local checks = math.max(1, math.floor(FRACTION * culled_count))
                    local start_idx = self.last_culled_index
                    
                    for i = 0, checks - 1 do
                        local idx = ((start_idx - 1 + i) % culled_count) + 1
                        local data = self.culled_units_list[idx]
                        
                        if data and now >= (data.time_to_consider or 0) then
                            local unit = data.unit
                            if unit and Unit.alive(unit) then
                                local pos = Unit.world_position(unit, 0)
                                local _, dist = CameraManager:is_position_inside_frustum(pos)
                                
                                if dist <= UNCULL_DIST then
                                    self:uncull_unit(unit)
                                else
                                    data.time_to_consider = now + math.max(0.1, (dist - UNCULL_DIST) * 0.02)
                                end
                            end
                        end
                    end
                    
                    self.last_culled_index = ((self.last_culled_index - 1 + checks) % culled_count) + 1
                end
            end)
        else
            -- Cooked lmao
        end
    end
    
    if path == "lua/ai_states/ai_manager" and not PerformanceChanges.hooks_applied.ai then
        PerformanceChanges.hooks_applied.ai = true
        
        Mods.hook:set(MOD_NAME, "AIManager.can_spawn_more", function(orig, self)
            local count = table.map_size(self._monsters)
            local can_spawn = count < PerformanceChanges.CONFIG.ai.max_monsters
            return can_spawn
        end)
        
        if PerformanceChanges.CONFIG.ai.disable_ai_culling then
            Mods.hook:set(MOD_NAME, "AIManager._cull_distant", function(orig, self)
                local num_unculled = 0
                for unit, _ in pairs(self._monsters) do
                    if not EntityCullingManager:is_culled(unit) then
                        num_unculled = num_unculled + 1
                    end
                end
                self._need_culling = false
                return num_unculled
            end)
        end
        
        Mods.hook:set(MOD_NAME, "AIManager._try_spawn_monster", function(orig, self, unit_path, position, ...)
            local spawn_args = {...}
            local spawn_args_n = select("#", ...)

            if self:is_paused() then return end
            if self._nr_monsters_spawned_this_frame >= PerformanceChanges.CONFIG.ai.max_spawns_per_frame then return end
            
            local num_unculled = 0
            for unit, _ in pairs(self._monsters) do
                if not EntityCullingManager:is_culled(unit) then
                    num_unculled = num_unculled + 1
                end
            end
            
            if num_unculled < PerformanceChanges.CONFIG.ai.max_monsters then
                return self:_do_spawn(unit_path, position, unpack(spawn_args, 1, spawn_args_n))
            end
            
            if EntityCullingManager:should_cull() then
                local _, dist = CameraManager:is_position_inside_frustum(position)
                if dist > 15 then
                    local unit, go_id = self:_do_spawn(unit_path, position, unpack(spawn_args, 1, spawn_args_n))
                    if unit then
                        EntityCullingManager:cull_unit(unit)
                    end
                    return unit, go_id
                end
            end
        end)
        
        Mods.hook:set(MOD_NAME, "AIManager.update", function(orig, self, dt)
            Profiler.start("AIManager:update")
            
            if self._ai_director then
                self._ai_director:update(dt)
            end
            
            if self._need_culling and not PerformanceChanges.CONFIG.ai.disable_ai_culling then
                self:_cull_distant()
            else
                self._need_culling = false
            end
            
            if self._is_host then
                local size = #self._delayed_spawns
                if size > 0 then
                    local max_to_process = PerformanceChanges.CONFIG.ai.max_spawns_per_frame
                    for i = size, math.max(1, size - max_to_process + 1), -1 do
                        if self._nr_monsters_spawned_this_frame < max_to_process then
                            local spawn = self._delayed_spawns[i]
                            if spawn then
                                local unit_path, position, rotation, parent_go_id, setup_info = unpack(spawn)
                                self:_try_spawn_monster(unit_path, Vector3Aux.unbox(position), QuaternionAux.unbox(rotation), parent_go_id, setup_info)
                                self._delayed_spawns[i] = nil
                            end
                        end
                    end
                end
                self._nr_monsters_spawned_this_frame = 0
            end
            
            Profiler.stop()
        end)
    end
    
    if path == "lua/states/state_game" and not PerformanceChanges.hooks_applied.state_game then
        PerformanceChanges.hooks_applied.state_game = true
        
        Mods.hook:set(MOD_NAME, "StateGame.on_enter", function(orig, self, params)
            orig(self, params)
            
            if PerformanceChanges.CONFIG.fps.unlock_fps then
                Application.set_time_step_policy("no_throttle")
            else
                Application.set_time_step_policy("throttle", PerformanceChanges.CONFIG.fps.target_fps)
            end
            
            if rawget(_G, "SurfaceEffectManager") then
                SurfaceEffectManager:set_max_decal_units(PerformanceChanges.CONFIG.visuals.max_decals)
            end
            
            if PerformanceChanges.CONFIG.gibs.fast_despawn and rawget(_G, "Despawner") then
                Despawner.DEFAULT_DESPAWN_WAIT_TIME = PerformanceChanges.CONFIG.gibs.despawn_wait_time
                Despawner.DEFAULT_DESPAWN_DECAY_TIME = PerformanceChanges.CONFIG.gibs.decay_duration
                Despawner.GIB_STATIC_LIGHT_WAIT_TIME = PerformanceChanges.CONFIG.gibs.gib_light_wait
                Despawner.GIB_STATIC_LIGHT_FADE_TIME = PerformanceChanges.CONFIG.gibs.gib_light_fade
            end
        end)
    end

    if path == "foundation/lua/managers/surface_effect_manager" and not PerformanceChanges.hooks_applied.surface_effect then
        PerformanceChanges.hooks_applied.surface_effect = true
        
        Mods.hook:set(MOD_NAME, "SurfaceEffectManager.update", function(orig, self, dt)
            Profiler.start("surface_effect: update")
            
            local FADE_OUT_TIME = PerformanceChanges.CONFIG.visuals.decal_fade_time
            local EMISSIVE_FADE_OUT_TIME = PerformanceChanges.CONFIG.visuals.emissive_fade_time
            
            while self.decal_units:size() > self.max_decal_units do
                local unit = self.decal_units:dequeue()
                self.fade_units[unit] = _G.GAME_TIME
            end
            
            for unit, emissive_time in pairs(self.emissive_units) do
                local t = (_G.GAME_TIME - emissive_time) / EMISSIVE_FADE_OUT_TIME
                if t < 1 then
                    MaterialAux.set_scalar(unit, nil, nil, "emissive_fade_code", t)
                else
                    self.emissive_units[unit] = nil
                end
            end
            
            for unit, fade_time in pairs(self.fade_units) do
                local t = (_G.GAME_TIME - fade_time) / FADE_OUT_TIME
                if t < 1 then
                    MaterialAux.set_scalar(unit, nil, nil, "transparency_code", t)
                else
                    self.fade_units[unit] = nil
                    self.emissive_units[unit] = nil
                    self.unit_sort_order[unit] = nil
                    World.destroy_unit(self.world, unit)
                end
            end
            
            Profiler.stop()
        end)
        
    end
    
    -- =========================================================================================
    -- GIB MANAGER HOOKS (Corpse handling)
    -- =========================================================================================
    if path == "lua/managers/gib_manager" and not PerformanceChanges.hooks_applied.gib_manager then
        PerformanceChanges.hooks_applied.gib_manager = true
        
        if PerformanceChanges.CONFIG.gibs.fast_despawn then
            Mods.hook:set(MOD_NAME, "GibManager.add_gib_unit", function(orig, self, unit, start_decay_time, decay_duration, character_depth, fadeout_times)
                local fast_start = start_decay_time or PerformanceChanges.CONFIG.gibs.despawn_wait_time
                local fast_decay = decay_duration or PerformanceChanges.CONFIG.gibs.decay_duration
                
                orig(self, unit, fast_start, fast_decay, character_depth, fadeout_times)
            end)
        end
        
    end
    
    if path == "lua/managers/despawner" and not PerformanceChanges.hooks_applied.despawner then
        PerformanceChanges.hooks_applied.despawner = true
        
        if PerformanceChanges.CONFIG.gibs.fast_despawn then
            Despawner.DEFAULT_DESPAWN_WAIT_TIME = PerformanceChanges.CONFIG.gibs.despawn_wait_time
            Despawner.DEFAULT_DESPAWN_DECAY_TIME = PerformanceChanges.CONFIG.gibs.decay_duration
            Despawner.GIB_STATIC_LIGHT_WAIT_TIME = PerformanceChanges.CONFIG.gibs.gib_light_wait
            Despawner.GIB_STATIC_LIGHT_FADE_TIME = PerformanceChanges.CONFIG.gibs.gib_light_fade
        end
    end
    
    if path == "lua/managers/platform" and not PerformanceChanges.hooks_applied.platform then
        PerformanceChanges.hooks_applied.platform = true
        
        if PerformanceChanges.CONFIG.fps.unlock_fps then
            Application.set_time_step_policy("no_throttle")
        else
            Application.set_time_step_policy("throttle", PerformanceChanges.CONFIG.fps.target_fps)
        end
    end
    
    return result
end)

PerformanceChanges.set_config = function(key, value)
    local keys = {}
    for k in string.gmatch(key, "[^.]+") do
        table.insert(keys, k)
    end
    
    local current = PerformanceChanges.CONFIG
    for i = 1, #keys - 1 do
        current = current[keys[i]]
        if not current then
            return false
        end
    end
    
    current[keys[#keys]] = value
    return true
end

PerformanceChanges.get_config = function()
    return PerformanceChanges.CONFIG
end

PerformanceChanges.uncull_all = function()
    if not rawget(_G, "EntityCullingManager") then
        return
    end
    
    local count = 0
    local culled_list = EntityCullingManager.culled_units_list
    if culled_list then
        for i = #culled_list, 1, -1 do
            local data = culled_list[i]
            if data and data.unit and Unit.alive(data.unit) then
                EntityCullingManager:uncull_unit(data.unit)
                count = count + 1
            end
        end
    end
end

PerformanceChanges.get_culling_status = function()
    if not rawget(_G, "EntityCullingManager") then
        return
    end
    
    local culled = #(EntityCullingManager.culled_units_list or {})
    local not_culled = #(EntityCullingManager.not_culled_units_list or {})
    local total = culled + not_culled
    
    return {culled = culled, visible = not_culled, total = total}
end

