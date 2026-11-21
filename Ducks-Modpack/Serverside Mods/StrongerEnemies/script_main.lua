
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "1.7.0"
local MOD_DESCRIPTION = "Add abilities to enemies."

local MOD_NAME, log_message = Mods.init_mod()

StrongerEnemies = StrongerEnemies or {}
StrongerEnemies.loaded = true

-- Saveable settings (persisted by the DucksUI menu through mod_settings.json).
-- Per-ability rows are created on demand by get_ability_option(), so an older save keeps its
-- chances and only gains the rows a new version adds.
StrongerEnemies.CONFIG = StrongerEnemies.CONFIG or {
    enabled = true,
}

-- Gates one enemy's extra abilities: the master toggle and that enemy's own toggle must both be on.
StrongerEnemies.is_enabled = function (enemy)
    local config = StrongerEnemies.CONFIG

    if not config or config.enabled == false then
        return false
    end

    local entry = config[enemy]

    if entry and entry.enabled == false then
        return false
    end

    return true
end

-- Drops the retired Nightmare Mode key; 1.6 saves still carry it and nothing reads it now.
StrongerEnemies.load_config = function ()
    StrongerEnemies.CONFIG.nightmare_mode = nil
end

-- =================================================================================================
-- Per-ability extras
--
-- One row per enemy ability the mod can top up. The enemy scripts roll a row through
-- roll_ability(), and the UI builds its checkbox and slider from this same table, so adding an
-- ability means adding one entry here and calling the helper from that ability's callback.
--
-- default_enabled keeps the old normal-mode behaviour: rows that used to sit behind Nightmare Mode
-- ship unchecked, the rest ship checked. legacy_key is the single per-enemy slider the old UI
-- saved and is only read while the new row has no value of its own.
-- =================================================================================================
StrongerEnemies.ABILITY_OPTIONS = {
    lich = {
        { id = "raise_skeletons",          label = "Raise Skeletons",  extra = "Storm Bomb", default_chance = 0.12, default_enabled = false, legacy_key = "storm_bomb_chance" },
        { id = "shadowbeam",               label = "Shadowbeam",       extra = "Storm Bomb", default_chance = 0.12, default_enabled = false, legacy_key = "storm_bomb_chance" },
        { id = "shadowbeam_left_to_right", label = "Shadowbeam (L-R)", extra = "Storm Bomb", default_chance = 0.12, default_enabled = false, legacy_key = "storm_bomb_chance" },
        { id = "shadowbeam_right_to_left", label = "Shadowbeam (R-L)", extra = "Storm Bomb", default_chance = 0.12, default_enabled = false, legacy_key = "storm_bomb_chance" },
        { id = "shadowdive_appear",        label = "Shadowdive",       extra = "Storm Bomb", default_chance = 1.00, default_enabled = false, legacy_key = "shadowdive_bomb_chance" },
        { id = "ghost_swarm",              label = "Ghost Swarm",      extra = "Storm Bomb", default_chance = 0.12, default_enabled = true,  legacy_key = "storm_bomb_chance" },
        { id = "on_spawn_raise_skeletons", label = "Spawn Skeletons",  extra = "Storm Bomb", default_chance = 0.12, default_enabled = false, legacy_key = "storm_bomb_chance" },
    },
    necromancer = {
        { id = "ice_field", label = "Ice Field", extra = "Orb of Winter",    default_chance = 0.50, default_enabled = true, legacy_key = "winter_orb_chance" },
        { id = "ice_beam",  label = "Ice Beam",  extra = "Lightning Shield", default_chance = 0.20, default_enabled = true, legacy_key = "shield_chance" },
    },
    mummy_bloated = {
        { id = "acid_bomber", label = "Acid Bomber", extra = "Poison Elemental", default_chance = 0.10, default_enabled = true, legacy_key = "acid_bomber_chance" },
        { id = "ice_bomber",  label = "Ice Bomber",  extra = "Ice Elemental",    default_chance = 0.10, default_enabled = true, legacy_key = "ice_bomber_chance" },
        { id = "fire_bomber", label = "Fire Bomber", extra = "Burning Blast",    default_chance = 0.10, default_enabled = true, legacy_key = "fire_bomber_chance" },
    },
    demon_heavy = {
        { id = "super_nova_start",       label = "Super Nova",       extra = "Sinister Orb",     default_chance = 1.00, default_enabled = true,  legacy_key = "super_nova_orb_chance" },
        { id = "super_nova_start_hover", label = "Super Nova",       extra = "Hover Orb",        default_chance = 1.00, default_enabled = false, legacy_key = "super_nova_hover_chance" },
        { id = "super_nova_event_data",  label = "Super Nova Bolts", extra = "Mortar Shot",      default_chance = 1.00, default_enabled = false, legacy_key = "super_nova_mortar_chance" },
        { id = "confusing_glare",        label = "Confusing Glare",  extra = "Lightning Shield", default_chance = 1.00, default_enabled = true,  legacy_key = "confusing_glare_shield_chance" },
        { id = "demon_egg",              label = "Demon Egg",        extra = "Sinister Orb",     default_chance = 1.00, default_enabled = true,  legacy_key = "demon_egg_orb_chance" },
    },
    spider_queen = {
        { id = "spin_web", label = "Spin Web", extra = "Gas Projectile", default_chance = 1.00, default_enabled = true, legacy_key = "spin_web_chance" },
        { id = "lay_eggs", label = "Lay Eggs", extra = "Gas Projectile", default_chance = 1.00, default_enabled = true, legacy_key = "lay_eggs_chance" },
    },
}

-- Indexed copy so a roll does not walk the option list.
local ability_option_index = {}

for enemy, options in pairs(StrongerEnemies.ABILITY_OPTIONS) do
    ability_option_index[enemy] = {}

    for _, option in ipairs(options) do
        ability_option_index[enemy][option.id] = option
    end
end

-- The enemy's saved table, created on demand so the UI can show an enemy that was never touched.
StrongerEnemies.get_enemy_config = function (enemy)
    local config = StrongerEnemies.CONFIG
    local entry = config[enemy]

    if type(entry) ~= "table" then
        entry = { enabled = true }
        config[enemy] = entry
    end

    return entry
end

-- One saved { enabled, chance } row for an enemy ability, seeded from the schema on first use.
StrongerEnemies.get_ability_option = function (enemy, ability_id)
    local option = ability_option_index[enemy] and ability_option_index[enemy][ability_id]

    if not option then
        return nil
    end

    local entry = StrongerEnemies.get_enemy_config(enemy)
    entry.abilities = entry.abilities or {}

    local ability = entry.abilities[ability_id]

    if type(ability) ~= "table" then
        ability = {}
        entry.abilities[ability_id] = ability
    end

    if ability.enabled == nil then
        ability.enabled = option.default_enabled ~= false
    end

    if ability.chance == nil then
        ability.chance = entry[option.legacy_key] or option.default_chance
    end

    return ability
end

-- Single roll shared by every enemy script: enemy toggle, row checkbox and chance in one place.
StrongerEnemies.roll_ability = function (enemy, ability_id)
    if not StrongerEnemies.is_enabled(enemy) then
        return false
    end

    local ability = StrongerEnemies.get_ability_option(enemy, ability_id)

    if not ability or ability.enabled == false then
        return false
    end

    return math.random() < ability.chance
end

-- Positions handed to the engine are untrusted: Unit.world_position and the navgrid queries return
-- INF/NaN when their source is gone, and an infinite position reaching a spawn or an ability target
-- spins the engine forever (the wave-2 freeze). NaN fails x == x; infinity fails the bound.
local POSITION_LIMIT = 100000

StrongerEnemies.is_finite_position = function (position)
    if position == nil then
        return false
    end

    local x, y, z = position.x, position.y, position.z

    return type(x) == "number" and type(y) == "number" and type(z) == "number"
        and x == x and y == y and z == z
        and math.abs(x) < POSITION_LIMIT and math.abs(y) < POSITION_LIMIT and math.abs(z) < POSITION_LIMIT
end

-- Ability commands are queued, not executed on this call. Engine vectors are recycled scratch
-- buffers, so unboxed positions must be copied into a fresh Vector3 before they go into a command:
-- reading the scratch later in the run returns nonsense (or INF), and the engine then spins.
StrongerEnemies.copy_position = function (position_box)
    if position_box == nil then
        return nil
    end

    local position = Vector3Aux.unbox(position_box)

    if not StrongerEnemies.is_finite_position(position) then
        return nil
    end

    return Vector3(position.x, position.y, position.z)
end

-- The target an ability event was given, in the form 1.6.4 handed to the engine. That build is the
-- one that did not hang, and the captures since have shown the freeze happens with perfectly valid
-- targets too, so nothing here second-guesses the event: the box goes through as-is, a bare position
-- is copied out of the recycled scratch buffer, and only a non-finite value is refused.
StrongerEnemies.event_target_position = function (event)
    if event == nil then
        return nil
    end

    if event.target_position_box ~= nil then
        return event.target_position_box
    end

    local position = event.target_position

    if not StrongerEnemies.is_finite_position(position) then
        return nil
    end

    return Vector3(position.x, position.y, position.z)
end

-- =================================================================================================
-- Ability ids
--
-- An ability instance is identified by a 3-bit ability_id packed into all of its event and hit ids
-- (goid | ability_id | event_index | hit -- lua/components/ability_aux.lua), and events are matched
-- back by that id, so two live abilities on one unit that share an id alias each other's events.
-- The engine hands ids out from a wrapping counter and never checks the live set.
-- =================================================================================================

local function ability_id_count()
    if AbilityAux == nil then
        return nil
    end

    return 2 ^ AbilityAux.BITS_ABILITY
end

local function mark_ability_ids(state, in_use)
    local abilities = state and state.active_abilities

    if not abilities then
        return false
    end

    for i = 1, #abilities do
        local ability_id = abilities[i].ability_id

        if ability_id ~= nil then
            in_use[ability_id] = true
        end
    end

    return true
end

-- Lowest id no live ability holds, nil when all 8 are taken or the live set cannot be read.
StrongerEnemies.find_free_ability_id = function (unit, state)
    local id_count = ability_id_count()

    if not id_count or not unit then
        return nil
    end

    local in_use = {}
    local known = mark_ability_ids(state, in_use)

    -- Master and slave share one ability_event_handler, so the id must be free in both lists.
    known = mark_ability_ids(EntityAux.state_master(unit, "ability"), in_use) or known
    known = mark_ability_ids(EntityAux.state(unit, "ability"), in_use) or known

    if not known then
        return nil
    end

    for ability_id = 0, id_count - 1 do
        if not in_use[ability_id] then
            return ability_id
        end
    end
end

-- Gate for a cast made by hand from another mod file.
StrongerEnemies.can_execute_ability = function (unit)
    return StrongerEnemies.find_free_ability_id(unit) ~= nil
end

-- Abilities the mod stacks, keyed "<settings_path>.<ability_name>". A guarded cast is dropped when
-- every id is taken, since running it would alias a live ability. Other mod files may add entries.
StrongerEnemies.guarded_abilities = StrongerEnemies.guarded_abilities or {
    ["equipment/wizard/weapon02.sinister_orb"] = true,
    ["equipment/wizard/weapon02.sinister_orb_hover"] = true,
}

StrongerEnemies.is_guarded_ability = function (settings_path, ability_name)
    if not settings_path or not ability_name then
        return false
    end

    return StrongerEnemies.guarded_abilities[settings_path .. "." .. ability_name] == true
end

-- Route the id to the next free slot instead of letting the wrapping counter land on a live ability.
Mods.hook:set_object_path("AbilityAux", "generate_ability_id", function(orig, unit, state)
    local free_id = StrongerEnemies.find_free_ability_id(unit, state)

    if free_id == nil then
        return orig(unit, state)
    end

    if state then
        -- Keep the counter aligned so the engine's own ability chains keep rotating.
        state.ability_id_counter = (free_id + 1) % ability_id_count()
    end

    return free_id
end, MOD_NAME .. ".ability_id_alloc", MOD_NAME)

-- The engine's append path (on_event_complete chains such as sinister_orb -> sinister_orb_hover)
-- never carries caster_unit, so the ability runs with caster_unit == nil and
-- AbilityComponent.update_active_abilities advances it with unscaled GAME_DT. Its own events do get
-- caster_unit and are scaled by that unit's animation_speed (AbilityAux.scale_delta_time), so off a
-- caster whose animation_speed is not 1 an ability's schedule drifts from its events and its effect
-- expires before the last ones fire. The execute path already falls back to the casting unit, so
-- mirror it.
Mods.hook:set_object_path("AbilityComponent", "append_ability", function(orig, self, unit, context, ability, ...)
    if ability and ability.caster_unit == nil then
        local caster_unit = ability.owner_unit

        if caster_unit == nil or not Unit.alive(caster_unit) then
            caster_unit = unit
        end

        ability.caster_unit = caster_unit
    end

    return orig(self, unit, context, ability, ...)
end, MOD_NAME .. ".append_caster", MOD_NAME)

-- Owned units run every cast through AbilityComponent.command_master, engine-driven chains
-- included, so dropping a guarded cast here covers them all.
--
-- The same hook traces the casts this mod starts: the heartbeat in freeze_heartbeat.txt names the
-- frame a freeze happened on, this names the ability that was being cast, which is what a spin in
-- the engine's aim math needs to be pinned on.
StrongerEnemies.traced_casts = StrongerEnemies.traced_casts or {
    ["storm_bomb"] = true,
    ["sinister_orb"] = true,
    ["sinister_orb_hover"] = true,
    ["orb_of_winter_hover"] = true,
    ["lightning_shield"] = true,
    ["mortar_shot"] = true,
    ["gas_projectile"] = true,
}

-- Positions in the trace: the freeze loop is a "retry until the direction is far enough from a
-- reference vector" test, so a NaN on either side is what has to be visible in the file.
local function fmt_position(position)
    if position == nil then
        return "nil"
    end

    local x, y, z = position.x, position.y, position.z

    if type(x) == "number" and type(y) == "number" and type(z) == "number" then
        return string.format("(%.2f,%.2f,%.2f)", x, y, z)
    end

    return "?"
end

StrongerEnemies.trace_cast = function (unit, ability_name, data)
    local duckmode = rawget(_G, "Duckmode")

    if type(duckmode) ~= "table" or type(duckmode.trace) ~= "function" then
        return
    end

    -- type() is replaced in this build (foundation/lua/base/patches.lua), so a Vector3 is not "table"
    -- here; test the fields instead of the type name, or every cast reads as "unit".
    local has_position = type(data) == "table" and data.target_position ~= nil
    local has_unit = type(data) == "table" and data.target_unit ~= nil
    local target_kind = has_position and "position" or (has_unit and "unit" or "no-target")
    local caster_position = Unit.world_position(unit, 0)

    duckmode.trace(string.format("%d %s caster=%s pos=%s finite=%s target=%s %s", os.time(),
        tostring(ability_name), tostring(Unit.get_data(unit, "unit_path")), fmt_position(caster_position),
        tostring(StrongerEnemies.is_finite_position(caster_position)),
        fmt_position(has_position and data.target_position or nil), target_kind), "freeze_casts")
end

-- A cast that was not queued is logged next to the ones that were: it is the interesting half.
StrongerEnemies.trace_skip = function (ability_name, unit, reason)
    local duckmode = rawget(_G, "Duckmode")

    if type(duckmode) ~= "table" or type(duckmode.trace) ~= "function" then
        return
    end

    duckmode.trace(string.format("%d skipped %s caster=%s pos=%s (%s)", os.time(), tostring(ability_name),
        tostring(Unit.get_data(unit, "unit_path")), fmt_position(Unit.world_position(unit, 0)),
        tostring(reason or "no usable target")), "freeze_casts")
end

Mods.hook:set_object_path("AbilityComponent", "command_master", function(orig, self, unit, context, command_name, data)
    local ability_name = type(data) == "table" and data.ability_name

    if ability_name then
        local settings_path = data.settings_path or Unit.get_data(unit, "settings_path")

        if StrongerEnemies.traced_casts[ability_name] then
            StrongerEnemies.trace_cast(unit, ability_name, data)
        end

        if StrongerEnemies.is_guarded_ability(settings_path, ability_name) and not StrongerEnemies.can_execute_ability(unit) then
            log_message("WARN", "Dropped " .. ability_name .. ": all ability ids are in use")

            return
        end
    end

    return orig(self, unit, context, command_name, data)
end, MOD_NAME .. ".ability_id_guard", MOD_NAME)

-- =================================================================================================
-- Orb statuses
--
-- weapon02's sinister_orb carries burning = true, which is right for the wizard but not for the
-- monsters the mod hands the same orb to: a fire orb thrown by an enemy should not set players on
-- fire. AbilityEventHandler.execute_event builds the event from a deep clone of the settings, so
-- dropping the status there only affects that one cast and leaves the wizard's orb alone.
--
-- The bloated mummy's fire bomber is the exception: its death blast is that same burst, and it is
-- meant to burn what it catches.
-- =================================================================================================
Mods.hook:set_object_path("AbilityEventHandler", "execute_event", function (orig, self, event_data, parent_ability, ...)
    local event = orig(self, event_data, parent_ability, ...)

    if not event then
        return event
    end

    local ability_name = event.ability_name

    if ability_name ~= "sinister_orb" and ability_name ~= "sinister_orb_hover" then
        return event
    end

    local caster_unit = event.caster_unit

    if not caster_unit or EntityAux.has_component_master(caster_unit, "avatar") then
        return event
    end

    event.settings.status_effects = nil

    if Unit.get_data(caster_unit, "is_fire_bomber") then
        event.settings.status_effects = {
            burning = true,
        }
    end

    return event
end, MOD_NAME .. ".orb_statuses", MOD_NAME)

