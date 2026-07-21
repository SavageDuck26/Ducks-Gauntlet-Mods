-- =================================================================================================
-- Author: SavageDuck26, Skapp
-- Purpose: Player manager hooks for Doppelgangers mod
-- =================================================================================================

local MOD_NAME = "DoppelPlayerManager"

-- Global player_manager toggle (set by main script)
player_manager_toggle = player_manager_toggle ~= false -- default to true unless set false

-- Hook the require function to modify classes after they're loaded
Mods.hook:set(MOD_NAME .. "_player_manager", "require", function(orig, path, ...)
    local result = orig(path, ...)
    -- Only run player_manager code if player_manager_toggle is true
    if player_manager_toggle and path == "foundation/lua/player/player_manager" and PlayerManager then
        -- Store original functions
        local original_register_local_avatar_unit = PlayerManager.register_local_avatar_unit
        local original_link_avatar = PlayerManager.link_avatar
        local original_get_player_info_by_avatar_type = PlayerManager.get_player_info_by_avatar_type
        
        -- Override register_local_avatar_unit - keep it simple like original
        PlayerManager.register_local_avatar_unit = function(self, player_go_id, avatar_unit)
            local info = self.player_infos[player_go_id]
            if not info then
                return
            end
            -- Use original approach - just call the master component and link
            EntityAux.call_master(info.player_unit, "player", "set_avatar", avatar_unit)
            self:link_avatar(player_go_id, avatar_unit)
        end
        
        -- Override link_avatar - simplified to match original game approach
        PlayerManager.link_avatar = function(self, player_unit_or_go_id, avatar_unit)
            local player_go_id = type(player_unit_or_go_id) == "number" and player_unit_or_go_id or self.entity_storage:go_id(player_unit_or_go_id)
            local player_info = self.player_infos[player_go_id]
            if not player_info then
                return
            end
            
            -- Initialize avatar tracking if needed
            if not self.avatar_go_id_to_player then
                self.avatar_go_id_to_player = {}
            end
            
            -- Clean up previous association (like original)
            if player_info.avatar_go_id then
                self.avatar_go_id_to_player[player_info.avatar_go_id] = nil
            end
            
            -- Link new avatar (like original)
            if Unit.alive(avatar_unit) then
                local avatar_go_id = self.entity_storage:go_id(avatar_unit)
                self.avatar_go_id_to_player[avatar_go_id] = player_info
                player_info.avatar_unit = avatar_unit
                player_info.avatar_go_id = avatar_go_id
                if self.event_delegate then
                    self.event_delegate:trigger("on_player_avatar_linked", player_go_id, avatar_unit)
                end
            else
                player_info.avatar_unit = nil
                player_info.avatar_go_id = nil
                if self.event_delegate then
                    self.event_delegate:trigger("on_player_avatar_unlinked", player_go_id)
                end
            end
        end
        
        -- NEW: Add function to get player info by avatar type AND peer_id (for doppelganger support)
        PlayerManager.get_player_info_by_avatar_type_and_peer = function(self, avatar_type, peer_id)
            if not self.player_infos then
                return nil
            end
            for go_id, info in self:players_iterator() do
                if info and info.avatar_type == avatar_type and info.peer_id == peer_id then
                    return info
                end
            end
            return nil
        end
        
        -- NEW: Get all players with a specific avatar type (for iterating over doppelgangers)
        PlayerManager.get_all_players_by_avatar_type = function(self, avatar_type)
            local players = {}
            if not self.player_infos then
                return players
            end
            for go_id, info in self:players_iterator() do
                if info and info.avatar_type == avatar_type then
                    players[#players + 1] = info
                end
            end
            return players
        end
        
        -- Override get_player_info_by_avatar_type - prefer LOCAL player when duplicates exist
        -- Cache to prevent repeated iteration during rapid gold pickup events (e.g., wizard gold pot)
        local player_info_cache = {}
        local cache_clear_time = 0
        local CACHE_DURATION = 0.1 -- Cache for 100ms to handle rapid events
        
        PlayerManager.get_player_info_by_avatar_type = function(self, avatar_type)
            if not self.player_infos then
                return original_get_player_info_by_avatar_type(self, avatar_type)
            end
            
            -- Clear cache periodically to prevent stale data
            local current_time = _G.GAME_TIME or 0
            if current_time - cache_clear_time > CACHE_DURATION then
                player_info_cache = {}
                cache_clear_time = current_time
            end
            
            -- Check cache first
            if player_info_cache[avatar_type] then
                return player_info_cache[avatar_type]
            end
            
            local my_peer_id = Network and Network.peer_id and Network.peer_id() or 1
            local first_match = nil
            local local_match = nil
            
            -- Use pcall to prevent crashes during rapid iteration
            local success, _ = pcall(function()
                -- Search for matches, preferring local player
                for go_id, info in self:players_iterator() do
                    if info and info.avatar_type == avatar_type then
                        if not first_match then
                            first_match = info
                        end
                        -- Prefer local player's info for HUD/voice targeting
                        if info.peer_id == my_peer_id then
                            local_match = info
                            break
                        end
                    end
                end
            end)
            
            if not success then
                -- Fallback to original if pcall failed
                return original_get_player_info_by_avatar_type(self, avatar_type)
            end
            
            -- Cache the result
            local result = local_match or first_match
            player_info_cache[avatar_type] = result
            
            -- Return local match if found, otherwise first match (maintains compatibility)
            return result
        end
        -- Override of get_player_info_by_avatar - add pcall protection for rapid gold events
        local original_get_player_info_by_avatar = PlayerManager.get_player_info_by_avatar
        PlayerManager.get_player_info_by_avatar = function(self, avatar_unit)
            local success, result = pcall(function()
                return original_get_player_info_by_avatar(self, avatar_unit)
            end)
            if success then
                return result
            end
            return nil
        end
        -- Override of get_player_info_by_avatar_go_id - add pcall protection
        local original_get_player_info_by_avatar_go_id = PlayerManager.get_player_info_by_avatar_go_id  
        PlayerManager.get_player_info_by_avatar_go_id = function(self, avatar_go_id)
            local success, result = pcall(function()
                return original_get_player_info_by_avatar_go_id(self, avatar_go_id)
            end)
            if success then
                return result
            end
            return nil
        end
        -- Override on_entity_unregistering to trigger events for ALL duplicate characters
        local original_on_entity_unregistering = PlayerManager.on_entity_unregistering
        PlayerManager.on_entity_unregistering = function(self, unit, go_id)
            -- Initialize tracking structures if they don't exist
            if not self.unregistering_avatars then
                self.unregistering_avatars = {}
            end
            if not self.avatar_go_id_to_player then
                self.avatar_go_id_to_player = {}
            end
            
            -- Check if this is a player unit (not avatar)
            if self.player_infos and self.player_infos[go_id] then
                self:unregister_player(unit)
                return
            end
            
            -- Check if this is an avatar unit that belongs to any player(s)
            local is_avatar_for_duplicates = false
            if self.avatar_go_id_to_player[go_id] then
                -- This avatar is tracked, handle duplicate cleanup
                for player_go_id, info in self:players_iterator() do
                    if info and info.avatar_unit == unit then
                        -- Mark for unregistration and trigger event for each duplicate
                        self.unregistering_avatars[unit] = go_id
                        if self.event_delegate then
                            self.event_delegate:trigger("on_player_avatar_unregistering", unit, info)
                        end
                        is_avatar_for_duplicates = true
                    end
                end
            end
            
            -- If not handled as duplicate avatar, call original function
            if not is_avatar_for_duplicates then
                original_on_entity_unregistering(self, unit, go_id)
            end
        end
        -- Override on_entity_unregistered to handle multiple players with same avatar
        local original_on_entity_unregistered = PlayerManager.on_entity_unregistered
        PlayerManager.on_entity_unregistered = function(self, unit)
            -- Initialize unregistering_avatars if it doesn't exist
            if not self.unregistering_avatars then
                self.unregistering_avatars = {}
            end
            
            local go_id = self.unregistering_avatars[unit]
            if go_id then
                -- Handle avatar unregistration for duplicates
                for player_go_id, info in self:players_iterator() do
                    if info.avatar_unit == unit then
                        info.avatar_unit = nil
                        info.avatar_go_id = nil -- Also clear the go_id reference
                    end
                end
                -- Clean up tracking structures
                if self.avatar_go_id_to_player then
                    self.avatar_go_id_to_player[go_id] = nil
                end
                self.unregistering_avatars[unit] = nil
            else
                -- CRITICAL FIX: Call original function for non-tracked entities
                original_on_entity_unregistered(self, unit)
            end
        end
        -- Override teardown to safely handle duplicate character cleanup
        local original_teardown = PlayerManager.teardown
        PlayerManager.teardown = function(self)
            -- Only clean up references to dead avatar units to prevent crashes
            if self.player_infos then
                for go_id, info in pairs(self.player_infos) do
                    if info and info.avatar_unit and not Unit.alive(info.avatar_unit) then
                        info.avatar_unit = nil
                    end
                end
            end
            -- Call original teardown
            original_teardown(self)
        end
    end
    return result
end)

