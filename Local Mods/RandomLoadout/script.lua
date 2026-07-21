-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.1
-- Purpose: Randomizes LOCAL player loadout (talisman, weapon, relic) each endless floor.
-- =================================================================================================

local MOD_NAME = "RandomLoadout"

local randomized_floors = {}
local randomized_local_players = {}
local pending_randomization = false
local current_floor = nil
local hud_refresh_needed = {}

local function get_random_from_table(tbl)
    if not tbl then
        return nil
    end
    
    local keys = {}
    for key, _ in pairs(tbl) do
        keys[#keys + 1] = key
    end
    
    if #keys == 0 then
        return nil
    end
    
    return keys[math.random(#keys)]
end

local function get_random_weapon(avatar_type, controller_name)
    if not HeroLoadout then
        return nil
    end
    
    local hero_loadout = HeroLoadout[avatar_type]
    if not hero_loadout then
        return nil
    end
    
    local weapons = hero_loadout["weapon"]
    if not weapons then
        return nil
    end
    
    -- Get user profile to check ownership
    local user = nil
    if ProfileManager and ProfileManager.get_user and controller_name then
        local ok, result = pcall(function() return ProfileManager:get_user(controller_name) end)
        if ok then
            user = result
        end
    end
    
    -- Build list of owned weapons
    local owned_weapons = {}
    for weapon_id, _ in pairs(weapons) do
        local is_owned = false
        
        if user and user.owns_avatar_item then
            local ok, level = pcall(function() return user:owns_avatar_item(avatar_type, weapon_id) end)
            if ok and level and level ~= false then
                is_owned = true
            end
        else
            is_owned = true
        end
        
        if is_owned then
            owned_weapons[#owned_weapons + 1] = weapon_id
        end
    end
    
    if #owned_weapons == 0 then
        return nil
    end
    
    return owned_weapons[math.random(#owned_weapons)]
end

local function get_random_talisman(avatar_type, controller_name)
    if not HeroLoadout then
        return nil
    end
    
    local hero_loadout = HeroLoadout[avatar_type]
    if not hero_loadout then
        return nil
    end
    
    local talismans = hero_loadout["talisman"]
    if not talismans then
        return nil
    end
    
    -- Get user profile to check ownership
    local user = nil
    if ProfileManager and ProfileManager.get_user and controller_name then
        local ok, result = pcall(function() return ProfileManager:get_user(controller_name) end)
        if ok then
            user = result
        end
    end
    
    -- Build list of owned talismans
    local owned_talismans = {}

    for talisman_id, _ in pairs(talismans) do
        local is_owned = false
        
        if user and user.owns_avatar_item then
            local ok, level = pcall(function() return user:owns_avatar_item(avatar_type, talisman_id) end)
            if ok and level and level ~= false then
                is_owned = true
            end
        else
            is_owned = true
        end
        
        if is_owned then
            owned_talismans[#owned_talismans + 1] = talisman_id
        end
    end
    
    if #owned_talismans == 0 then
        return nil
    end
    
    return owned_talismans[math.random(#owned_talismans)]
end

-- Get a random relic that the player actually owns for this avatar
local function get_random_relic(avatar_type, controller_name)
    if not RelicsIds then
        return nil
    end
    
    -- Get user profile to check ownership
    local user = nil
    if ProfileManager and ProfileManager.get_user and controller_name then
        local ok, result = pcall(function() return ProfileManager:get_user(controller_name) end)
        if ok then
            user = result
        end
    end
    
    -- Build list of owned relics
    local owned_relics = {}
    for relic_id, relic in pairs(RelicsIds) do
        local is_owned = false
        
        if user and user.owns_avatar_item and avatar_type then
            local ok, level = pcall(function() return user:owns_avatar_item(avatar_type, relic_id) end)
            if ok and level and level ~= false then
                is_owned = true
            end
        else
            -- If we can't check ownership, assume owned (fallback)
            is_owned = true
        end
        
        if is_owned then
            owned_relics[#owned_relics + 1] = relic_id
        end
    end
    
    if #owned_relics == 0 then
        return nil
    end

    local random_relic = owned_relics[math.random(#owned_relics)]

    while random_relic == "relic_golden_feather" do
        random_relic = owned_relics[math.random(#owned_relics)]
    end    
    
    return random_relic
end

local function randomize_local_player_loadout(player_info)
    if not player_info then
        return false
    end
    
    if not player_info.is_local_player then
        return false
    end
    
    local avatar_type = player_info.avatar_type
    if not avatar_type then
        return false
    end
    
    local loadout_ids = player_info.loadout_ids
    if not loadout_ids then
        if ProfileManager and ProfileManager.get_user then
            local ok, user = pcall(function() return ProfileManager:get_user(player_info.controller_name) end)
            if ok and user and user.get_loadout_ids_for then
                local fallback = user:get_loadout_ids_for(avatar_type)
                if fallback then
                    player_info.loadout_ids = fallback
                    loadout_ids = fallback
                end
            end
        end
    end

    if not loadout_ids then
        return false
    end
    
    local controller_name = player_info.controller_name
    
    local random_weapon = get_random_weapon(avatar_type, controller_name)
    if random_weapon then
        local ok, settings = pcall(function() return ItemLookup.item_id_to_settings(random_weapon) end)
        if ok and settings then
            loadout_ids.weapon = random_weapon
        else
            -- Nothing
        end
    end

    local random_talisman = get_random_talisman(avatar_type, controller_name)
    if random_talisman then
        local ok, settings = pcall(function() return ItemLookup.item_id_to_settings(random_talisman) end)
        if ok and settings then
            loadout_ids.talisman = random_talisman
        else
            -- Nothing
        end
    end

    local random_relic = get_random_relic(avatar_type, controller_name)
    if random_relic then
        local ok, settings = pcall(function() return ItemLookup.item_id_to_settings(random_relic) end)
        if ok and settings then
            loadout_ids.relic = random_relic
        else
            -- Nothing
        end
    end
        
    return true
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "lua/managers/endless_client" then
        
        Mods.hook:set(MOD_NAME, "EndlessClient.set_floor_index", function(orig, self, floor_index, previous_floor_index, ...)
            local ok, err = pcall(function()

                if floor_index ~= current_floor then
                    current_floor = floor_index
                    pending_randomization = true
                    randomized_local_players = {}  -- Reset list
                end
            end)

            if not ok then
                -- Nothing
            end

            return orig(self, floor_index, previous_floor_index, ...)
        end)
    end
    
    if path == "lua/states/game_client" then
        
        Mods.hook:set(MOD_NAME, "GameClient.spawn_avatar", function(orig, self, player_go_id, position, rotation, hitpoint_ratio, ...)
            
            local extra_args = {...}
            local unpack_fn = table.unpack or unpack

            local did_randomize = false
            local success_randomize = false

            if pending_randomization then
                if PlayerManager and PlayerManager.get_player_info then
                    local player_info = PlayerManager:get_player_info(player_go_id)

                    if player_info and player_info.is_local_player and not randomized_local_players[player_go_id] then
                        local ok, err = pcall(function()
                            success_randomize = randomize_local_player_loadout(player_info)
                        end)

                        if not ok then
                            -- Nothing
                        else
                            if success_randomize then
                                did_randomize = true
                            end
                        end
                    end
                end
            end

            local spawn_result = nil
            local ok, err = xpcall(function()
                spawn_result = orig(self, player_go_id, position, rotation, hitpoint_ratio, unpack_fn(extra_args))
            end, function(e)
                return debug.traceback(e)
            end)

            if not ok then
                return spawn_result
            end

            if did_randomize then
                randomized_local_players[player_go_id] = true
                hud_refresh_needed[player_go_id] = true
            end

            return spawn_result
        end)

        Mods.hook:set(MOD_NAME, "GameClient.on_world_loaded", function(orig, self, seed, floor, ...)
            local ret = orig(self, seed, floor, ...)

            local ok, err = pcall(function()
                if floor ~= current_floor then
                    current_floor = floor
                    pending_randomization = true
                    randomized_local_players = {}  -- Reset list
                end
            end)

            if not ok then
                -- Nothing
            end

            return ret
        end)
    end
    
    if path == "lua/ui/player_hud" then
        
        Mods.hook:set(MOD_NAME, "PlayerHud.update_widget", function(orig, self, dt, go_id, ...)
            local ok, err = pcall(function()
                if self.relic_refresh_counter == nil then
                    self.relic_refresh_counter = 0
                end

                local needs_refresh = hud_refresh_needed[go_id]
                if needs_refresh then
                    hud_refresh_needed[go_id] = nil
                    self.relic_refresh_counter = math.max(self.relic_refresh_counter, 10)
                    self.talisman = nil
                    self.relic = nil
                end

                local relic_blank = (self.relic == false or self.relic == nil or self.relic == "")
                if relic_blank and self.relic_refresh_counter > 0 then
                    self.talisman = nil
                    self.relic = nil
                    self.relic_refresh_counter = self.relic_refresh_counter - 1
                end
            end)

            if not ok then
                -- Nothing
            end

            return orig(self, dt, go_id, ...)
        end)
    end

    return result
end)