-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.6
-- Purpose: Randomizes local players character each endless floor.
-- =================================================================================================

local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.6.0"
local MOD_DESCRIPTION = "Randomizes each local player's character every endless floor."

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/RandomHero/RandomHero.lua")

RandomHero = RandomHero or {}
RandomHero.loaded = true

-- The switch uses the engine's own hero change: drop the local player, then let the host re-add it
-- on the new hero. drop_user destroys the player_info, so the fresh one the host re-adds carries none
-- of the state the engine keeps there between floors (spawn_avatar reads it back out): the inventory
-- pair, the carried gold and the health fraction. Snapshot them before the drop and hand them to the
-- new player_info so the re-spawned hero keeps them.
local SWITCH_DELAY = 0.05

-- Floor detection state.
local current_floor = nil
local pending_randomization = false
local randomized_this_floor = false

-- In-flight switch state.
local is_switching = false
local random_hero_override = nil
local switch_controller_name = nil
local saved_state = {}             -- controller_name -> { num_potions, num_keys, gold, hitpoint_ratio }
local switching_controllers = {}   -- controller_name -> true while its player is dropped
local respawn_hitpoint_ratio = nil -- health fraction to give the hero spawned to finish a switch
local respawn_controller_name = nil

local function note_floor(floor)
    if floor ~= current_floor then
        current_floor = floor
        pending_randomization = true
        randomized_this_floor = false
    end
end

-- The host refuses a drop-in on a hero the party already uses (PartyLeadManager.is_avatar_type_in_use)
-- and answers by dumping the player into the character select screen. Doppelgangers forces that
-- check to false, so only then may the roll land on a hero another player is already using.
local function duplicates_allowed()
    return Doppelgangers and Doppelgangers.loaded == true
end

local function get_random_avatar(current_avatar)
    local unavailable = {}

    if not duplicates_allowed() then
        for _, player_info in PlayerManager:players_iterator() do
            if player_info.avatar_type then
                unavailable[player_info.avatar_type] = true
            end
        end
    end

    local available = {}

    for _, avatar in ipairs(AvatarSettings.avatars) do
        if avatar ~= current_avatar and not unavailable[avatar] then
            available[#available + 1] = avatar
        end
    end

    if #available == 0 then
        return nil
    end

    return available[math.random(#available)]
end

local function do_character_switch(game_client, controller_name, new_hero)
    local player_info = PlayerManager:get_player_info_by_controller_name(controller_name)

    if player_info then
        local hitpoint_ratio = nil

        -- Keep the fraction, not the raw hitpoints, since the new hero has its own max health.
        -- PartyManager refreshes these fields from the live avatar every frame.
        if player_info.hitpoints and player_info.max_hitpoints and player_info.max_hitpoints > 0 then
            hitpoint_ratio = math.saturate(player_info.hitpoints / player_info.max_hitpoints)
        end

        saved_state[controller_name] = {
            num_potions = player_info.num_potions or 0,
            num_keys = player_info.num_keys or 0,
            gold = player_info.gold,
            hitpoint_ratio = hitpoint_ratio,
        }
    end

    is_switching = true
    random_hero_override = new_hero
    switch_controller_name = controller_name
    switching_controllers[controller_name] = true

    game_client:drop_user(controller_name)
    game_client.entity_spawner:delete_marked_entities()
    game_client:try_join(controller_name)
end

local function finish_character_switch(game_client, player_go_id)
    local controller_name = switch_controller_name
    local player_info = PlayerManager:get_player_info(player_go_id)
    local saved = saved_state[controller_name]

    -- spawn_avatar copies these straight out of player_info: num_potions/num_keys seed the inventory
    -- component and gold seeds the gold gatherer (endless), so restoring them here is what conserves
    -- the player's potions, keys and gold across the switch.
    if player_info and saved then
        player_info.num_potions = saved.num_potions
        player_info.num_keys = saved.num_keys
        player_info.gold = saved.gold
    end

    -- Health is different: spawn_avatar only reads player_info.hitpoints while the player is in the
    -- "exited_floor" state, which the switch is not, so remember the fraction and let the spawn_avatar
    -- hook hand it to the engine when the new hero is actually spawned.
    if saved and saved.hitpoint_ratio then
        respawn_hitpoint_ratio = saved.hitpoint_ratio
        respawn_controller_name = controller_name
    end

    local new_hero = random_hero_override
    local loadout_ids = nil

    if ProfileManager and ProfileManager.get_user then
        local user = ProfileManager:get_user(controller_name)

        if user and user.get_loadout_ids_for then
            loadout_ids = user:get_loadout_ids_for(new_hero)
        end
    end

    saved_state[controller_name] = nil
    switching_controllers[controller_name] = nil
    is_switching = false
    random_hero_override = nil
    switch_controller_name = nil
    game_client.selecting_character = nil

    -- Avatar_type is nil on the player find_or_create_player_for_controller just made, so
    -- hero_selected adopts it and sends the drop-in request the host turns into a spawn.
    game_client:hero_selected(controller_name, new_hero, loadout_ids)
end

-- A fresh run reuses the same floor numbers, so clear the cached floor when EndlessClient starts;
-- otherwise a run that begins on the floor the previous one ended on never randomizes floor 1.
Mods.hook:set_object_path("EndlessClient", "setup", function(orig, self, state_game)
    current_floor = nil

    return orig(self, state_game)
end, MOD_NAME .. ".EndlessClient.setup", MOD_NAME)

Mods.hook:set_object_path("EndlessClient", "set_floor_index", function(orig, self, floor_index, previous_floor_index, ...)
    note_floor(floor_index)

    return orig(self, floor_index, previous_floor_index, ...)
end, MOD_NAME .. ".EndlessClient.set_floor_index", MOD_NAME)

Mods.hook:set_object_path("GameClient", "try_join", function(orig, self, controller_name, ...)
    if is_switching and random_hero_override and controller_name == switch_controller_name then
        -- Skip the character select screen: claim the slot and let from_server_slot_request_reply
        -- finish the switch once the host answers.
        self.selecting_character = controller_name
        self.network_router:transmit_to(self.host_id, "from_client_slot_request", controller_name)

        return
    end

    return orig(self, controller_name, ...)
end, MOD_NAME .. ".GameClient.try_join", MOD_NAME)

Mods.hook:set_object_path("GameClient", "from_server_slot_request_reply", function(orig, self, sender, controller_name, success, ...)
    if is_switching and random_hero_override and controller_name == switch_controller_name then
        if success then
            local player_go_id = self:find_or_create_player_for_controller(controller_name)

            finish_character_switch(self, player_go_id)
        else
            -- Slot refused: drop the in-flight state and leave the player to rejoin normally.
            saved_state[controller_name] = nil
            switching_controllers[controller_name] = nil
            respawn_hitpoint_ratio = nil
            respawn_controller_name = nil
            is_switching = false
            random_hero_override = nil
            switch_controller_name = nil
        end

        return
    end

    return orig(self, sender, controller_name, success, ...)
end, MOD_NAME .. ".GameClient.from_server_slot_request_reply", MOD_NAME)

Mods.hook:set_object_path("GameClient", "spawn_avatar", function(orig, self, player_go_id, position, rotation, hitpoint_ratio, ...)
    local player_info = PlayerManager:get_player_info(player_go_id)

    -- The hero spawned to finish a switch arrives from the host with no ratio (the engine only sends
    -- one when it remembers the drop itself), so feed it the fraction the player had before the switch
    -- and the new hero keeps the same health instead of being healed to full. A fresh player_info has
    -- no avatar yet, which is what separates this re-spawn from a later revive of a live hero.
    local is_switch_respawn = respawn_hitpoint_ratio ~= nil and player_info and player_info.is_local_player
        and player_info.controller_name == respawn_controller_name and player_info.avatar_unit == nil

    if is_switch_respawn then
        if hitpoint_ratio == nil then
            hitpoint_ratio = respawn_hitpoint_ratio
        end

        respawn_hitpoint_ratio = nil
        respawn_controller_name = nil
    end

    local spawn_result = orig(self, player_go_id, position, rotation, hitpoint_ratio, ...)

    if pending_randomization and not randomized_this_floor and not is_switching then
        if player_info and player_info.is_local_player and player_info.controller_name then
            randomized_this_floor = true
            pending_randomization = false

            local new_hero = get_random_avatar(player_info.avatar_type)

            if new_hero then
                local controller_name = player_info.controller_name

                -- spawn_avatar is still on the stack, and drop_user would destroy the avatar the
                -- engine is mid-spawn of. Let it return before tearing the player down.
                AddUtility.delay_action(SWITCH_DELAY, function()
                    do_character_switch(self, controller_name, new_hero)
                end)
            end
        end
    end

    return spawn_result
end, MOD_NAME .. ".GameClient.spawn_avatar", MOD_NAME)

-- drop_user reads to the host as the player leaving, and GameServer.on_player_unregistered answers by
-- dropping that player's keys/potions on the floor - loot the player never walks back to, while the
-- switch already restored the count. When the host is the peer running the switch (single-player or
-- the host machine) swallow the drop for that controller so the inventory is not left behind twice.
-- On a pure client this hook never fires: the host, which does not share this state, owns that call.
Mods.hook:set_object_path("InventoryComponent", "drop_inventory_on_player_drop", function(orig, entity_spawner, player_info, position)
    if player_info and switching_controllers[player_info.controller_name] then
        return
    end

    return orig(entity_spawner, player_info, position)
end, MOD_NAME .. ".InventoryComponent.drop_inventory_on_player_drop", MOD_NAME)
