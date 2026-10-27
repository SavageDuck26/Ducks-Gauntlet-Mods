
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.7.0"
local MOD_DESCRIPTION = "Randomizes each local player's character every endless floor."

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/RandomHero/RandomHero.lua")

RandomHero = RandomHero or {}
RandomHero.loaded = true

-- A refused drop-in (the host refuses a hero the party already uses, and two modded clients can roll
-- the same hero) is re-rolled and retried after a jittered 0.1-0.4s delay, instead of letting the
-- engine answer it with the character select screen (game_client.lua:1545-1549).
--
-- The switch uses the engine's own hero change: drop the local player, then let the host re-add it
-- on the new hero. drop_user destroys the player_info, so the fresh one the host re-adds carries none
-- of the state the engine keeps there between floors (spawn_avatar reads it back out): the inventory
-- pair, the carried gold and the health fraction. Snapshot them before the drop and hand them to the
-- new player_info so the re-spawned hero keeps them.
local SWITCH_DELAY = 0.05

-- A refused drop-in (the hero was already taken -- two modded clients can roll the same one) is
-- re-rolled and retried after a short jittered delay, so two clients that collided do not keep
-- colliding. The engine's own answer to a refusal is the character select screen
-- (game_client.lua:1545-1549), which is what this avoids.
local RETRY_MIN = 0.1
local RETRY_MAX = 0.4
local MAX_SWITCH_RETRIES = 8

-- A number derived from this peer's id, for spreading retries between peers. Network.peer_id() is a
-- STRING in this game (a hex steam id like "11000013f20422c"), so it has to be read as one -- doing
-- arithmetic on it directly is a crash.
local function peer_seed()
    local peer_id = (type(Network) == "table" and type(Network.peer_id) == "function")
        and Network.peer_id() or nil

    if type(peer_id) == "number" then
        return peer_id
    end

    if type(peer_id) == "string" then
        -- The tail of a hex id, or a plain decimal read, or failing that the byte sum -- any of them
        -- just has to differ between peers.
        local value = tonumber(string.sub(peer_id, -4), 16) or tonumber(peer_id)

        if type(value) == "number" and value == value then
            return value
        end

        local sum = 0

        for i = 1, #peer_id do
            sum = sum + string.byte(peer_id, i)
        end

        return sum
    end

    return 0
end

-- Random, but nudged by this peer: two clients that collided share the same math.random sequence
-- (LuaJIT's default seed is the same in every process, and os.* is not available to mods), so a plain
-- random() would put them back in lockstep. The peer offset spreads them across the window instead.
local function retry_delay()
    local slot = (math.random() + (peer_seed() % 4) / 4) % 1

    return RETRY_MIN + slot * (RETRY_MAX - RETRY_MIN)
end

-- The spawn position in GameClient.spawn_avatar is host data arriving over the network
-- (from_server_spawn_avatar*), and a revive with no living friend to fall back on can leave it
-- non-finite. The engine spawns the avatar straight at it and spins, so validate before the engine
-- call: NaN fails x == x, infinity fails the magnitude bound, so one check covers both.
local POSITION_LIMIT = 100000

local function is_finite(position)
    if not position then
        return false
    end

    local x, y, z = position.x, position.y, position.z

    return x == x and y == y and z == z
        and math.abs(x) < POSITION_LIMIT and math.abs(y) < POSITION_LIMIT and math.abs(z) < POSITION_LIMIT
end

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
local refused_heroes = {}          -- hero name -> true, for the switch in flight (a hero the host refused)
local switch_retries = 0           -- how many times the switch in flight has been re-rolled

-- The drop-in we are waiting on: finish_character_switch clears the switch state (and is_switching)
-- BEFORE it asks the host, so the refusal that comes back has to be matched by something else.
local pending_join = nil           -- { controller_name = ..., hero = ... }
local respawn_hitpoint_ratio = nil -- health fraction to give the hero spawned to finish a switch
local respawn_controller_name = nil


local stashed_inventory = {}   -- controller_name -> { num_keys, num_potions }

local function stash_inventory(player_info)
    if not player_info or not player_info.controller_name then
        return nil
    end

    local stashed = stashed_inventory[player_info.controller_name]

    if stashed then
        return stashed
    end

    stashed = {
        num_keys = player_info.num_keys or 0,
        num_potions = player_info.num_potions or 0,
    }

    stashed_inventory[player_info.controller_name] = stashed

    return stashed
end

-- Empty the pockets on this board and on the master copy, so replication carries the empty counts to
-- the host (the master is what the host's copy of the avatar is refreshed from).
local function empty_inventory(player_info)
    player_info.num_keys = 0
    player_info.num_potions = 0

    if player_info.avatar_unit then
        EntityAux.command_master_immediately(player_info.avatar_unit, "inventory", "clear_keys_and_potions")
    end
end

local function restore_inventory(player_info, stashed)
    if not player_info or not stashed then
        return
    end

    player_info.num_keys = stashed.num_keys
    player_info.num_potions = stashed.num_potions
end

-- Hand the stashed loot back to a player who is STAYING on this avatar: player_info for the next seed,
-- and the live inventory component too, because player_info is refreshed from that component every
-- frame (party_manager.lua:107-130) and would otherwise be zeroed again on the next update.
local function refill_inventory(player_info, stashed)
    if not player_info or not stashed then
        return
    end

    restore_inventory(player_info, stashed)

    local unit = player_info.avatar_unit

    if not unit then
        return
    end

    for _ = 1, stashed.num_keys do
        EntityAux.command_master_immediately(unit, "inventory", "add_key")
    end

    for _ = 1, stashed.num_potions do
        EntityAux.command_master_immediately(unit, "inventory", "add_potion")
    end
end

-- A refused switch leaves the player with no avatar (drop_user already ran), so the stash is simply
-- kept: whenever that controller's next avatar spawns -- a manual rejoin from character select, or the
-- next floor -- the counts go back onto the new player_info. Nothing was dropped on the way out, so
-- the loot is conserved either way.
local function keep_stash_for_next_spawn(controller_name)
    local stashed = stashed_inventory[controller_name]

    if stashed then
        log_message(string.format("switch refused for %s: keeping %d key(s) and %d potion(s) for the next spawn",
            tostring(controller_name), stashed.num_keys, stashed.num_potions))
    end

    return stashed
end

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
-- NOTE: Doppelgangers is an optional mod, so its global may not exist at all.
-- strict.lua errors on reading an undeclared global, so read it with rawget.
local function duplicates_allowed()
    local doppelgangers = rawget(_G, "Doppelgangers")

    return doppelgangers ~= nil and doppelgangers.loaded == true
end

-- Which heroes this player may switch to.
--
-- The engine's own list comes from the HOST: GameClient.on_party_changed strips the heroes the party
-- is already using before calling set_available_heroes, and the host's drop-in gate
-- (PartyLeadManager.is_avatar_type_in_use) is what built it. Picking from that list therefore cannot
-- be refused by a host that does not run this mod -- and when the host DOES run Doppelgangers, the
-- list is the whole roster, so duplicates stay possible exactly where they are allowed.
--
-- The local recomputation below is the fallback for when the engine has not published a list (or
-- published an empty one, which is the five-heroes-five-players case).
local function is_excluded(avatar, current_avatar, excluded)
    return avatar == current_avatar or (excluded ~= nil and excluded[avatar] == true)
end

local function get_random_avatar(game_client, current_avatar, excluded)
    local available = {}
    local engine_list = game_client and game_client.available_heroes

    if type(engine_list) == "table" then
        for _, avatar in ipairs(engine_list) do
            if not is_excluded(avatar, current_avatar, excluded) then
                available[#available + 1] = avatar
            end
        end
    end

    if #available == 0 then
        local unavailable = {}

        if not duplicates_allowed() then
            for _, player_info in PlayerManager:players_iterator() do
                if player_info.avatar_type then
                    unavailable[player_info.avatar_type] = true
                end
            end
        end

        for _, avatar in ipairs(AvatarSettings.avatars) do
            if not unavailable[avatar] and not is_excluded(avatar, current_avatar, excluded) then
                available[#available + 1] = avatar
            end
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
            gold = player_info.gold,
            hitpoint_ratio = hitpoint_ratio,
        }
    end

    is_switching = true
    random_hero_override = new_hero
    switch_controller_name = controller_name
    switching_controllers[controller_name] = true
    pending_join = nil
    refused_heroes = {}
    switch_retries = 0

    -- Potions and keys: normally already stashed and zeroed when the player walked into the floor exit,
    -- which is where the margin is. If this switch is happening without that (the first floor of a run),
    -- do it now -- late, but still ahead of the despawn.
    if player_info then
        stash_inventory(player_info)
        empty_inventory(player_info)
    end

    AddUtility.delay_action(SWITCH_DELAY, function()
        game_client:drop_user(controller_name)
        game_client.entity_spawner:delete_marked_entities()
        game_client:try_join(controller_name)
    end)
end

-- Ask the host for a hero: avatar_type is nil on the player_info the switch created, so hero_selected
-- adopts this hero and sends the drop-in request the host turns into a spawn. Also the retry path.
local function select_hero(game_client, controller_name, new_hero)
    local loadout_ids = nil

    if ProfileManager and ProfileManager.get_user then
        local user = ProfileManager:get_user(controller_name)

        if user and user.get_loadout_ids_for then
            loadout_ids = user:get_loadout_ids_for(new_hero)
        end
    end

    pending_join = { controller_name = controller_name, hero = new_hero }

    game_client:hero_selected(controller_name, new_hero, loadout_ids)
end

local function finish_character_switch(game_client, player_go_id)
    local controller_name = switch_controller_name
    local player_info = PlayerManager:get_player_info(player_go_id)
    local saved = saved_state[controller_name]

    -- Gold seeds the gold gatherer out of player_info (endless). Potions and keys are NOT restored
    -- here: they are in stashed_inventory, and the spawn_avatar hook writes them back onto the fresh
    -- player_info immediately before the engine seeds the new avatar's inventory from it.
    if player_info and saved then
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

    saved_state[controller_name] = nil
    switching_controllers[controller_name] = nil
    refused_heroes = {}
    switch_retries = 0
    is_switching = false
    random_hero_override = nil
    switch_controller_name = nil
    game_client.selecting_character = nil

    select_hero(game_client, controller_name, new_hero)
end

-- Leaving the floor: the player walked into the exit, or the floor-end pass is moving everyone along.
-- This is the moment to empty the pockets and stash the counts -- seconds ahead of the next floor's
-- spawn, which is when the switch unregisters the player, and long enough for the empty inventory to
-- reach the host. That is what makes this work with a host that does not run this mod.
Mods.hook:set_object_path("GameClient", "make_player_exit_floor", function(orig, self, player_info, ...)
    -- Only during an endless run: current_floor is set from EndlessClient.set_floor_index, so
    -- adventure mode (which never touches that) keeps its behaviour exactly as it was.
    if player_info and player_info.is_local_player and current_floor ~= nil then
        stash_inventory(player_info)

        if (player_info.num_keys or 0) > 0 or (player_info.num_potions or 0) > 0 then
            log_message(string.format("floor exit: stashed %d key(s) and %d potion(s) for %s",
                player_info.num_keys or 0, player_info.num_potions or 0,
                tostring(player_info.controller_name)))
        end

        empty_inventory(player_info)
    end

    return orig(self, player_info, ...)
end, MOD_NAME .. ".GameClient.make_player_exit_floor", MOD_NAME)

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
            -- Slot refused: keep the stashed loot for that controller's next spawn (a refused switch
            -- must not cost the player their potions), then drop the in-flight state and leave the
            -- player to rejoin normally.
            keep_stash_for_next_spawn(controller_name)

            pending_join = nil
            refused_heroes = {}
            switch_retries = 0
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

-- The host refuses a drop-in on a hero the party is already using (PartyLeadManager
-- :is_avatar_type_in_use, game_server.lua:776) and the engine answers a refusal by dumping the player
-- into the character select screen (game_client.lua:1545-1549). Two modded clients rolling at the same
-- moment collide exactly that way, and the losing player should not have to pick manually: re-roll
-- (never back onto a hero this board has already been refused) and retry after a short jittered delay.
local function retry_refused_join(game_client, player_go_id)
    local attempt = pending_join
    local player_info = PlayerManager:get_player_info(player_go_id)

    if not attempt or not player_info or player_info.controller_name ~= attempt.controller_name then
        return false
    end

    local refused = attempt.hero

    if refused then
        refused_heroes[refused] = true
    end

    -- The engine clears this on a refusal; the next hero_selected needs it nil to adopt the new hero.
    player_info.avatar_type = nil

    switch_retries = switch_retries + 1

    local next_hero = get_random_avatar(game_client, nil, refused_heroes)

    if next_hero == nil or switch_retries > MAX_SWITCH_RETRIES then
        log_message(string.format("join for %s refused %d time(s); leaving it to the character select",
            tostring(attempt.controller_name), switch_retries))

        pending_join = nil
        refused_heroes = {}
        switch_retries = 0

        return false
    end

    local delay = retry_delay()

    log_message(string.format("join for %s refused (hero %s was taken); retrying with %s in %.2fs",
        tostring(attempt.controller_name), tostring(refused), tostring(next_hero), delay))

    AddUtility.delay_action(delay, function()
        if pending_join ~= attempt then
            return
        end

        -- The player may be gone by now (the host dropped them, or they left): drop the attempt
        -- instead of leaving it armed for some later refusal to trip over.
        if not PlayerManager:get_player_info_by_controller_name(attempt.controller_name) then
            log_message(string.format("retry for %s abandoned: that player is gone",
                tostring(attempt.controller_name)))

            pending_join = nil
            refused_heroes = {}
            switch_retries = 0

            return
        end

        select_hero(game_client, attempt.controller_name, next_hero)
    end)

    return true
end

Mods.hook:set_object_path("GameClient", "from_server_player_drop_in_reply", function(orig, self, sender, player_go_id, accepted, ...)
    if not accepted and retry_refused_join(self, player_go_id) then
        -- Swallow the refusal, or the engine puts this player in the character select screen.
        return nil
    end

    local result = orig(self, sender, player_go_id, accepted, ...)

    if accepted and pending_join ~= nil then
        pending_join = nil
        refused_heroes = {}
        switch_retries = 0
    end

    return result
end, MOD_NAME .. ".GameClient.from_server_player_drop_in_reply", MOD_NAME)

Mods.hook:set_object_path("GameClient", "spawn_avatar", function(orig, self, player_go_id, position, rotation, hitpoint_ratio, ...)
    -- The position is host data arriving over the network (from_server_spawn_avatar*); a revive
    -- with no living friend to fall back on can leave it non-finite and the engine spawns the
    -- avatar straight at it. Swap in the camera focus before the engine ever sees a bad value.
    if not is_finite(position) then
        position = CameraManager:get_focus_position()
    end

    local player_info = PlayerManager:get_player_info(player_go_id)

    -- Is THIS the spawn that is about to trigger a hero switch? If so the pockets have to stay empty:
    -- the switch unregisters the player, and the host drops whatever its copy of player_info holds.
    -- Putting the stashed potions back here was the last bug -- the host read them again and dropped
    -- them, so the player both kept and lost them. The switch spends the stash on its own re-spawn.
    local will_switch = pending_randomization and not randomized_this_floor and not is_switching
        and player_info ~= nil and player_info.is_local_player == true
        and player_info.controller_name ~= nil

    local stashed = player_info and stashed_inventory[player_info.controller_name]

    if stashed and not will_switch then
        -- No switch coming: this avatar is the one the player keeps, so the loot goes back on
        -- player_info BEFORE the engine call, which is what seeds the inventory from it
        -- (game_client.lua:955-956).
        restore_inventory(player_info, stashed)
        stashed_inventory[player_info.controller_name] = nil
    end

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

            local new_hero = get_random_avatar(self, player_info.avatar_type)

            if new_hero then
                local controller_name = player_info.controller_name

                -- spawn_avatar is still on the stack, and drop_user would destroy the avatar the
                -- engine is mid-spawn of. Let it return before tearing the player down.
                AddUtility.delay_action(SWITCH_DELAY, function()
                    do_character_switch(self, controller_name, new_hero)
                end)
            else
                -- Nothing could be rolled (every hero is taken, or the engine published an empty
                -- list), so no switch is coming and this avatar is the one the player keeps. The
                -- stash was held back for the switch, so hand it over now -- to the component as
                -- well, since player_info is refreshed from it every frame.
                local held = stashed_inventory[player_info.controller_name]

                if held then
                    log_message(string.format("no hero to roll for %s: keeping this avatar, %d key(s) and %d potion(s) restored",
                        tostring(player_info.controller_name), held.num_keys, held.num_potions))

                    refill_inventory(player_info, held)
                    stashed_inventory[player_info.controller_name] = nil
                end
            end
        end
    end

    return spawn_result
end, MOD_NAME .. ".GameClient.spawn_avatar", MOD_NAME)

-- drop_user reads to the host as the player leaving, and GameServer.on_player_unregistered answers by
-- dropping that player's keys/potions on the floor - loot the player never walks back to, while the
-- switch already restored the count. This hook owns both halves of that problem.
--
-- It runs on the HOST: drop_user only despawns the units, and the despawn is what makes every board
-- unregister the player; only GameServer.on_player_unregistered drops loot.
--
--   1. The board that is running the switch swallows its own drop. player_info.is_local_player is
--      per-board state, and the check needs it: two machines both call their first pad "xinput_0",
--      so a host switching its own player used to swallow the drop for any remote player with the
--      same controller name (their loot silently stayed in their pockets instead of on the floor).
--
--   2. A switch on ANOTHER peer cannot be swallowed here - this board has no switching_controllers
--      entry for it - and the counts it reads are its own copy, which the client's cleared inventory
--      reaches on the replication cadence, not before the despawn. Deciding now is what duplicated
--      every potion and key for non-host players. So the drop is HELD for DROP_GRACE: a real leave
--      still drops its loot, and a switch (which re-joins a frame or two later) cancels it.
local DROP_GRACE = 1.5
local pending_drops = {}

-- Keyed by the peer as well as the controller name: "xinput_0" is what every machine calls its first
-- pad, so the name alone cannot tell one player's re-join from another's.
local function forget_pending_drop(peer_id, controller_name)
    for i = #pending_drops, 1, -1 do
        local pending = pending_drops[i]

        if pending.controller_name == controller_name
            and (pending.peer_id == nil or peer_id == nil or pending.peer_id == peer_id) then
            table.remove(pending_drops, i)

            log_message(string.format("drop for peer %s (%s) cancelled: that player rejoined (switch)",
                tostring(pending.peer_id), tostring(controller_name)))
        end
    end
end

Mods.hook:set_object_path("InventoryComponent", "drop_inventory_on_player_drop", function(orig, entity_spawner, player_info, position)
    if type(player_info) ~= "table" then
        return orig(entity_spawner, player_info, position)
    end

    if player_info.is_local_player and switching_controllers[player_info.controller_name] then
        return
    end

    local pending = {
        peer_id = player_info.peer_id,
        controller_name = player_info.controller_name,
        keys = player_info.num_keys or 0,
        potions = player_info.num_potions or 0,
        player_info = player_info,
        position = position,
    }

    pending_drops[#pending_drops + 1] = pending

    AddUtility.delay_action(DROP_GRACE, function()
        for i = #pending_drops, 1, -1 do
            if pending_drops[i] == pending then
                table.remove(pending_drops, i)

                -- The counts are what this board held when the player left; put them back in case
                -- anything zeroed the player_info while the drop was held.
                pending.player_info.num_keys = pending.keys
                pending.player_info.num_potions = pending.potions

                return orig(entity_spawner, pending.player_info, pending.position)
            end
        end
    end)
end, MOD_NAME .. ".InventoryComponent.drop_inventory_on_player_drop", MOD_NAME)

-- The re-join half of the switch: try_join asks the host for a slot before the new hero is selected,
-- so this is the first thing a returning player sends.
Mods.hook:set_object_path("GameServer", "from_client_slot_request", function(orig, self, sender, controller_name, ...)
    forget_pending_drop(sender, controller_name)

    return orig(self, sender, controller_name, ...)
end, MOD_NAME .. ".GameServer.from_client_slot_request", MOD_NAME)
