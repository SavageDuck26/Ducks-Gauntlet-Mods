-- =================================================================================================
-- Author: SavageDuck26
-- Version: 2.3
-- Purpose: Main function file to control other scripts
-- =================================================================================================

local MOD_NAME = "AddUtility"

_G.is_host_ducks_mods = _G.is_host_ducks_mods or false

_G.check_host_ducks_mods = function(lobby)
    if lobby then
        local is_host = lobby:lobby_host() == Network.peer_id()
        _G.is_host_ducks_mods = is_host

        return _G.is_host_ducks_mods
    end
    return false
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/managers/lobby_manager" then
        Mods.hook:set(MOD_NAME, "LobbyManager.update", function(orig, self, dt)
            orig(self, dt)

            if self._network_lobby then
                _G.check_host_ducks_mods(self._network_lobby)
            end

            AddUtility.update(dt)
        end)
    end

    if path == "lua/states/state_game" then
        Mods.hook:set(MOD_NAME, "StateGame.on_exit", function(orig, self, ...)
            orig(self, ...)

            AddUtility.clear_updates()

            AddUtility.clear_active_messages()

        end)
    end

    return result
end)
-- =================================================================================================
-- =================================================================================================
-- =================================================================================================
AddUtility = {}

-- Update Functions
AddUtility._update_callbacks = {}
AddUtility.register_update = function(id, fn)
    AddUtility._update_callbacks[id] = fn
end
AddUtility.unregister_update = function(id)
    AddUtility._update_callbacks[id] = nil
end
AddUtility.clear_updates = function()
    AddUtility._update_callbacks = {}
end
AddUtility.update = function(dt)
    if not rawget(_G, "PlayerManager") then return end
    if not dt then dt = _G.GAME_DT end

    for id, fn in pairs(AddUtility._update_callbacks) do
        fn(dt)
    end
end
-- =================================================================================================
-- Avatar Functions
AddUtility.get_self_avatar_unit = function()
    for go_id, player_info in PlayerManager:local_avatars_iterator() do
        if player_info.avatar_unit then 
            return player_info.avatar_unit 
        end
    end
    return nil
end

AddUtility.get_dead_heroes = function()
    local dead_list = {}
    
    for go_id, player_info in PlayerManager:avatars_iterator() do
        local avatar_unit = player_info.avatar_unit
        
        if avatar_unit then
            local unit_alive = Unit.alive(avatar_unit)
            local has_dr_component = EntityAux.has_component(avatar_unit, "avatar_damage_receiver")
            local is_alive = DamageReceiverComponent.is_alive(avatar_unit)
                        
            if unit_alive and has_dr_component and not is_alive then
                table.insert(dead_list, { unit = avatar_unit, player_info = player_info, go_id = go_id })
            end
        else
            print("[AddUtility]   avatar_unit is nil")
        end
    end
    
    -- print("[AddUtility] get_dead_heroes: Found " .. #dead_list .. " dead heroes")

    return dead_list
end
-- =================================================================================================
-- Destroy Functions
--Auto-kill; often crashes if done on timed components.
AddUtility.destroy_unit = function(unit)
    if unit and Unit.alive(unit) then
        local world = FlowCallbacks.state_game and FlowCallbacks.state_game.world_proxy and FlowCallbacks.state_game.world_proxy:get_world()
        if world then
            World.destroy_unit(world, unit)
        else
            -- Nothing, didn't work
        end
    else
        -- Nothing, didn't work
    end
end

AddUtility.damage_unit = function(unit, damage_amount)
    local DAMAGE_AMOUNT = damage_amount or 99999

    if Unit.alive(unit) then
        EntityAux.call_interface(unit, "i_hit_receiver", "hit", {
            damage_amount = DAMAGE_AMOUNT,
            settings = {
                hit_react = "push",
            },
            modifiers = {},
            direction = Vector3Aux.box_temp(-UnitAux.unit_forward(unit)),
            position = Vector3Aux.box_temp(Unit.world_position(unit, 0)),
            random_seed = math.random() * 1000,
        })
    end
end
-- =================================================================================================
-- Spawning Functions
AddUtility.spawn_entity = function(path, spawn_at_unit) -- Spawn only ENTITIES at another unit.
    -- Sanity check 1
    if path == nil or spawn_at_unit == nil then
        print("AddUtility.spawn_entity: Invalid argument(s).")
        return
    end

    local short_unit_lookup = nil
    do
        local ok, t = pcall(require, "lua/generated/unit_paths_short_lookup")
        if ok and type(t) == "table" then
            short_unit_lookup = t
        else
            short_unit_lookup = {}
        end
    end

    -- Sanity check 3
    local unit_path = path
    if short_unit_lookup and short_unit_lookup[path] then
        unit_path = short_unit_lookup[path]
    else
        print("AddUtility.spawn_entity: unit path not found in short lookup.")
        return
    end

    local entity_spawner = FlowCallbacks.state_game and FlowCallbacks.state_game.entity_spawner
    if not entity_spawner then
        print("AddUtility.spawn_entity: No EntitySpawner available.")
        return
    end

    local position = Unit.world_position(spawn_at_unit, 0)
    local rotation = Unit.world_rotation(spawn_at_unit, 0)

    local ok, unit_or_err = pcall(function()
        return entity_spawner:spawn_entity(unit_path, position, rotation)
    end)

    if not ok or not unit_or_err then
        print("AddUtility.spawn_entity: Failed to spawn entity. Error: " .. tostring(unit_or_err))
        return nil
    end

    -- Register unit for networking and return
    if NetworkUnitSynchronizer and NetworkUnitSynchronizer.add then
        pcall(function() NetworkUnitSynchronizer:add(unit_or_err) end)
    end

    return unit_or_err
end

AddUtility.spawn_unit = function(path, spawn_at_unit) -- Spawn GENERIC UNITS at another unit.
    -- Sanity check 1
    if path == nil or spawn_at_unit == nil then
        print("AddUtility.spawn_unit: Invalid argument(s).")
        return
    end

    local short_unit_lookup = nil
    do
        local ok, t = pcall(require, "lua/generated/unit_paths_short_lookup")
        if ok and type(t) == "table" then
            short_unit_lookup = t
        else
            short_unit_lookup = {}
        end
    end

    local unit_path = path
    if short_unit_lookup and short_unit_lookup[path] then
        unit_path = short_unit_lookup[path]
    else
        print("AddUtility.spawn_unit: unit path not found in short lookup.")
        return
    end

    local world = FlowCallbacks.state_game and FlowCallbacks.state_game.world_proxy and FlowCallbacks.state_game.world_proxy:get_world()
    if not world then
        print("AddUtility.spawn_unit: No world available to spawn unit.")
        return
    end

    local position = Unit.world_position(spawn_at_unit, 0)
    local rotation = Unit.world_rotation(spawn_at_unit, 0)

    local ok, spawned_unit = pcall(function()
        return World.spawn_unit(world, unit_path, position, rotation)
    end)

    if not ok or not spawned_unit then
        print("AddUtility.spawn_unit: World.spawn_unit failed: " .. tostring(spawned_unit))
        return nil
    end

    if NetworkUnitSynchronizer and NetworkUnitSynchronizer.add then
        pcall(function() NetworkUnitSynchronizer:add(spawned_unit) end)
    end

    return spawned_unit
end

AddUtility.spawn_flow_unit = function(flow_event, parent_unit) -- NEEDS THE GLOBAL LOOKUP TO HAVE THE FLOW PATH
    local path_to_spawn
    for unit_path, event in pairs(_G.UnitFlowLookup or {}) do
        if event == flow_event then
            path_to_spawn = unit_path
            break
        end
    end

    local unit = AddUtility.spawn_unit(path_to_spawn, parent_unit)
    if unit then
        AddUtility.trigger_unit_flow_event(unit, flow_event)
        
        AddUtility.set_unit_visibility(unit, false)

        local destroy_id = "spawn_flow_unit_destroy_" .. tostring(unit) .. "_parent_" .. tostring(parent_unit)

        AddUtility.register_update(destroy_id, function(dt)
            if not EntityAux.is_alive_entity(parent_unit) then
                AddUtility.destroy_unit(unit)
                AddUtility.unregister_update(destroy_id)
            end
        end)
    end

    return unit
end

-- =================================================================================
-- Anim and Flow Functions
AddUtility.trigger_unit_animation = function(unit, animation_event)
    local anim_comp = EntityAux and EntityAux.get_component and EntityAux.get_component("animation", unit)

    if anim_comp then
        anim_comp:queue_command(unit, "animation", "trigger_event", animation_event)
    else
        print("[" .. MOD_NAME .. "] No animation component found for: " .. tostring(unit))
    end
end

-- Can only be used on units that HAVE the flow event already.
AddUtility.trigger_unit_flow_event = function(unit, flow_event)
    Unit.flow_event(unit, flow_event)
end
-- =================================================================================================
-- Unit Application Functions
AddUtility.set_unit_invincibility = function(unit, toggle) -- True or False
    local t = TempTableFactory:get_map("id", "invincible", "state", toggle and "on" or "off")
    EntityAux.queue_command_interface(unit, "i_damage_receiver", "set_invincibility", t)
end

-- True or False
AddUtility.set_unit_visibility = function(unit, toggle)
    Unit.set_unit_visibility(unit, toggle and true or false)
end
-- =================================================================================================
-- Time Functions
AddUtility.delay_action = function(duration, fn)
    Game.scheduler:delay_action(duration, function()
        fn()
    end)
end
-- =================================================================================================
-- =================================================================================================
-- =================================================================================================
-- Show Message Functions
local active_msgs = {}

-- helpers for managing active messages by id
local add_active_msg = function(id, widget)
    if not id then
        return
    end

    -- if another message with this id exists, destroy it immediately
    for i, entry in ipairs(active_msgs) do
        if entry.id == id then
            hide_ui_msg(entry.widget)
            table.remove(active_msgs, i)
            break
        end
    end

    table.insert(active_msgs, {id = id, widget = widget})
end

local remove_active_msg_by_widget = function(widget)
    for i, entry in ipairs(active_msgs) do
        if entry.widget == widget then
            table.remove(active_msgs, i)
            return
        end
    end
end

local msg_map_pos = {
    top = {"center", "top + 20"},
    top_left = {"center - 200", "top + 20"},
    top_right = {"center + 200", "top + 20"},
    center = {"center", "center"},
    center_left = {"center - 200", "center"},
    center_right = {"center + 200", "center"},
    bottom = {"center", "bottom - 20"},
    bottom_left = {"center - 200", "bottom - 20"},
    bottom_right = {"center + 200", "bottom - 20"},
}

local show_ui_msg = function(msg)
    -- convert definition to a widget instance so it has proper methods like do_layout
    local widget = GUI:load_proto(msg)
    GUI:add_widget(widget)
    return widget
end

local hide_ui_msg = function(widget)
    if not widget then
        return
    end

    -- destroy the widget and remove from active table if present
    GUI:destroy_widget(widget)
    remove_active_msg_by_widget(widget)
end

local check_active_msg = function(msg_id)
    for _, msg in pairs(active_msgs) do
        if msg.id == msg_id then
            return true
        end
    end

    return false
end

AddUtility.show_text = function(position, text, duration, color, font_size, msg_id)

    local old_widget

    -- if an active message with this id exists, remove it from the list but don't destroy yet
    if msg_id then
        for i, entry in ipairs(active_msgs) do
            if entry.id == msg_id then
                old_widget = entry.widget
                table.remove(active_msgs, i)
                break
            end
        end
    end

    local msg = {
        top_priority = 0,
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            {
                position = {"center", "center"},
                size = {"100%", "100%"},
                type = "container",
                children = {
                    {
                        id = msg_id,
                        type = "label",
                        text = text,
                        font_size = font_size or 48,
                        color = color or "purple",
                        position = msg_map_pos[position] or {"center", "center"},
                    },
                },
            },
        },
    }

    local widget = show_ui_msg(msg)

    if msg_id then
        table.insert(active_msgs, {id = msg_id, widget = widget})
    end

    if old_widget then
        hide_ui_msg(old_widget)
    end
    
    AddUtility.delay_action(duration, function()
        hide_ui_msg(widget)
    end)

end

AddUtility.clear_active_messages = function()
    for _, entry in ipairs(active_msgs) do
        GUI:destroy_widget(entry.widget)
    end
    active_msgs = {}
end

AddUtility.send_text_chat = function(tag, text)
    if not text or text == "" then
        return
    end

    local send_text = "[" .. tag .. "] " .. text

    local state_game = FlowCallbacks.state_game
    if not state_game then
        print("[AddUtility] send_text_chat: No state_game available.")
        return
    end

    local network_router = state_game.network_router
    if not network_router then
        print("[AddUtility] send_text_chat: No network_router available.")
        return
    end

    local avatar_type = nil
    for go_id, player_info in PlayerManager:local_avatars_iterator() do
        if player_info.avatar_type then
            avatar_type = player_info.avatar_type
            break
        end
    end

    if not avatar_type then
        print("[AddUtility] send_text_chat: Could not determine avatar_type.")
        return
    end

    network_router:transmit_to_all_others("rpc_text_chat", avatar_type, send_text)

    local text_chat = state_game.game_client and state_game.game_client.game_hud and state_game.game_client.game_hud.text_chat
    if text_chat and text_chat._history then
        local entry = {
            time = _G.ENGINE_TIME,
            peer_id = Network.peer_id(),
            avatar_type = avatar_type,
            text = send_text,
        }
        text_chat._history:enqueue(entry)

        local history_widget = text_chat._widget and text_chat._widget:get("history")
        if history_widget then
            history_widget:set_visible_instant(true)
            GUI.need_update[history_widget] = true
        end
    end
end
-- =================================================================================================