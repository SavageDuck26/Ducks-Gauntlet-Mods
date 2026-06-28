-- =================================================================================================
-- Author: SavageDuck26
-- Version: 2.0
-- Purpose: Adds more crowns to enemies
-- =================================================================================================

local MOD_NAME = "MoreCrowns"

MoreCrowns = MoreCrowns or {}
MoreCrowns.loaded = true

-- Saveable settings
MoreCrowns.CONFIG = MoreCrowns.CONFIG or {
    enabled = true,
    drop_chance = 0.25,
    crown_pickup_ui = true,
}

MoreCrowns.crowns_held_currently = MoreCrowns.crowns_held_currently or {}
MoreCrowns.crowns_picked_up_total = MoreCrowns.crowns_picked_up_total or {}
MoreCrowns.crowns_picked_up_floor = MoreCrowns.crowns_picked_up_floor or {}

local CROWN_DROP_DIVISOR = 2

local function get_crown_chance()
    -- Return 0 if mod is disabled
    if not MoreCrowns.CONFIG.enabled then
        return
    end
    return MoreCrowns.CONFIG.drop_chance or 0.25
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "gui/screen_lobby_ui" then
        get_crown_chance()
    end
    
    if path == "lua/ai_states/ai_manager" then
        Mods.hook:set(MOD_NAME, "AIManager._on_monster_spawned", function(orig, self, monster_unit, ...)
            if not MoreCrowns.CONFIG.enabled then
                return orig(self, monster_unit, ...)
            end

            if not self._is_host then
                return orig(self, monster_unit, ...)
            end

            if self._layout.treasures == false then
                return orig(self, monster_unit, ...)
            end

            local monster_settings = LuaSettingsManager:get_settings_by_unit(monster_unit)
            local treasure_joints = monster_settings.treasure_joints

            if not treasure_joints then
                return orig(self, monster_unit, ...)
            end

            local treasure_component = self._entity_manager:get_component("treasure")
            local treasure_types = TempTableFactory:get()

            for _, treasure_id in ipairs(TreasureComponent.TREASURES) do
                if treasure_joints[treasure_id] then -- REMOVED: and not treasure_component:has_any_of(treasure_id)
                    local unit_path = sprintf("gameobjects/treasures/%s/%s", treasure_id, treasure_id)
                    local settings = require(unit_path).treasure
                    local spawn_chance = get_crown_chance()

                    treasure_types[#treasure_types + 1] = TempTableFactory:get_map("unit_path", unit_path, "weight", spawn_chance)
                end
            end

            if #treasure_types > 0 then
                local pick = self._randomizer:array_weighted_value(treasure_types, 1)

                if pick then
                    self._entity_spawner:spawn_entity(pick.unit_path, nil, nil, nil, {
                        carrier = monster_unit,
                    })
                end
            end
        end)
    end

    if path == "lua/components/treasure_component" then
        local DROP_ENABLE_INTERACTABLE_WAIT = 1
        local DESPAWN_TIME = 10
        local DROP_FLY_SPEED = 10

        local function random_neg1_to_1()
            return math.random() * 2 - 1
        end

        Mods.hook:set(MOD_NAME, "TreasureComponent.init", function(orig, self, creation_context)
            orig(self, creation_context)
            self.crown_pickup_counts = {}
        end)

        Mods.hook:set(MOD_NAME, "TreasureComponent.pickup_master", function(orig, self, treasure_unit, treasure_state, carrier)
            local player_info = PlayerManager:get_player_info_by_avatar(carrier)
            local player_name = player_info and (player_info.name or player_info.display_name or player_info.player_name) or "Unknown Player"

            -- Check if carrier already has a crown
            local has_crown = false
            for unit, context in self.entity_manager:all_masters_iterator(self.name) do
                if context.state.carrier == carrier then
                    has_crown = true
                    break
                end
            end
            
            -- Always count the crown pickup for tracking purposes
            if player_info then
                MoreCrowns.crowns_held_currently[player_name] = (MoreCrowns.crowns_held_currently[player_name] or 0) + 1
                MoreCrowns.crowns_picked_up_total[player_name] = (MoreCrowns.crowns_picked_up_total[player_name] or 0) + 1
                MoreCrowns.crowns_picked_up_floor[player_name] = (MoreCrowns.crowns_picked_up_floor[player_name] or 0) + 1
            end
            
            if has_crown then
                self.entity_spawner:despawn_entity(treasure_unit)
            else
                orig(self, treasure_unit, treasure_state, carrier)
            end
        end)
        -- ================================================================================================================
        Mods.hook:set(MOD_NAME, "TreasureComponent.drop_master", function (orig, self, treasure_unit, treasure_state)
            local carrier = treasure_state.carrier

            if not carrier then
                return
            end

            EntityAux.queue_command_master(treasure_unit, "physics", "enable", "treasure_carried")
            EntityEventModifierManager:unregister_modifier(carrier, "knockbacked", "treasure")
            self.event_delegate:unregister_unit(carrier, treasure_state, "unit_on_death")
            Game:delay_action(DROP_ENABLE_INTERACTABLE_WAIT, function ()
                if Unit.alive(treasure_unit) then
                    self:queue_command_master(treasure_unit, "interactable", "set_enabled", true)
                end
            end)

            local player_info = PlayerManager:get_player_info_by_avatar(carrier)
            local player_name = player_info and (player_info.name or player_info.display_name or player_info.player_name) or "Unknown Player"
            -- ================================================================================================================
            if player_info then
                local held = MoreCrowns.crowns_held_currently[player_name] or 0
                for i = 1, (held / CROWN_DROP_DIVISOR) do
                    local drop = "gameobjects/treasures/crown/crown"

                    local entity_spawner = FlowCallbacks.state_game.entity_spawner
                    local position = Unit.world_position(carrier, 0) + Vector3(math.random(-0.5, 0.5), math.random(-0.5, 0.5), 0)
                    local rotation = Quaternion.from_yaw_pitch_roll(math.random() * math.pi * 2, 0, 0)
                    local dropped_unit = entity_spawner:spawn_entity(drop, position, rotation)

                    Unit.create_actor(dropped_unit, "dynamic", 0)
                    local actor = Unit.actor(dropped_unit, 0)
                    local base_vel_dir = -UnitAux.unit_forward(carrier)
                    base_vel_dir.z = 1
                    local vel_dir = base_vel_dir + Vector3(math.random(-0.1, 0.1), math.random(-0.1, 0.1), 0)
                    Actor.add_velocity(actor, vel_dir * DROP_FLY_SPEED)
                    Actor.add_angular_velocity(actor, Vector3(random_neg1_to_1(), random_neg1_to_1(), random_neg1_to_1()) * 20)

                    Unit.flow_event(dropped_unit, "on_dropped")
                    self:trigger_rpc_event_to_others("flow_event", dropped_unit, "on_dropped")
                    self:queue_command_master(dropped_unit, "interactable", "set_enabled", false)
                    Game:delay_action(DROP_ENABLE_INTERACTABLE_WAIT, function ()
                        if Unit.alive(dropped_unit) then
                            self:queue_command_master(dropped_unit, "interactable", "set_enabled", true)
                        end
                    end)

                    NetworkUnitSynchronizer:add(dropped_unit)
                end
                MoreCrowns.crowns_held_currently[player_name] = 0
            end
            -- ================================================================================================================
            if player_info then
                local owner = player_info.peer_id

                if owner == Network.peer_id() then
                    self.network_router:trigger_to_me("rpc_treasure_dropped", player_info.player_unit, treasure_unit)

                else
                    self:trigger_rpc_event_to(owner, "rpc_treasure_dropped", player_info.player_unit, treasure_unit)

                end
            end
            treasure_state.carrier = nil
            treasure_state.dropped_time = _G.GAME_TIME
        end)
    end

    return result
end)
