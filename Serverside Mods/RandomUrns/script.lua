
local MOD_AUTHOR = "SavageDuck26"
local MOD_VERSION = "5.1.0"
local MOD_DESCRIPTION = "Makes urns and goldrocks drops random things (Barrels, skullcoins, potions, stones, keys.)"

-- LAVA CRATES CANNOT BE CHANGED. THEY INSTA-CRASH THE GAME IF MODIFIED.
-- This note above should be correct. However it's not. I don't know why, for some reason now it works.
-- I have learned that the lava_metalbox uses the goldrock as a base, that's why it works now.

local MOD_NAME, log_message = Mods.init_mod(nil, "mods/RandomUrns/RandomUrns.lua")
RandomUrns = RandomUrns or {}

RandomUrns.loaded = true

-- Every droppable in the mod, shared by the drop pool and the config UI.
-- The ids are the save keys in mod_settings.json, so do not rename existing ones.
RandomUrns.drop_table = {
    { id = "carry_barrels", label = "Explosive Barrel", path = "gameobjects/carry/carry_barrel_crypt" },
    { id = "barrel_caves", label = "Caves Barrel", path = "gameobjects/carry/carry_barrel_caves" },
    { id = "barrel_lava", label = "Lava Barrel", path = "gameobjects/carry/carry_barrel_lava" },
    { id = "blue_potions", label = "Potions", path = "gameobjects/potions/potion_blue" },
    { id = "elemental_haste", label = "Elemental Haste", path = "gameobjects/carry/elemental_haste" },
    { id = "elemental_heal", label = "Elemental Heal", path = "gameobjects/carry/elemental_heal" },
    { id = "elemental_ice", label = "Elemental Ice", path = "gameobjects/carry/elemental_ice" },
    { id = "gold_small", label = "Small Gold Pile", path = "gameobjects/gold/pile_small" },
    { id = "gold_medium", label = "Medium Gold Pile", path = "gameobjects/gold/pile_medium" },
    { id = "gold_large", label = "Large Gold Pile", path = "gameobjects/gold/pile_large" },
    { id = "keys_small", label = "Key", path = "gameobjects/keys/small" },
}

-- Props that roll on the big-prop chance. Everything else that smashes rolls
-- on the small-prop chance. The urn, goldrock and cart paths are listed here
-- too, because their death handlers roll the big chance as well.
RandomUrns.big_props = {
    "props/d01_lava/lava_torture_device_01",
    "props/d01_lava/vase",
    "props/d01_caves/spideregg_01",
    "props/d01_common/box_small_01",
    "props/d01_common/barrel_01",
    "props/d01_common/barrel_01_rotten",
    "gameobjects/gold/urn",
    "gameobjects/gold/goldrock",
    "props/d01_caves/cart_smashable",
}

local function is_big_prop(unit_path)
    for _, pattern in ipairs(RandomUrns.big_props) do
        if string.find(unit_path, pattern, 1, true) then
            return true
        end
    end

    return false
end

-- Saveable settings
RandomUrns.CONFIG = RandomUrns.CONFIG or {
    drop_chance_small = 0.01,
    drop_chance_big = 0.20,
    small_props_enabled = true,
    big_props_enabled = true,
    drop_types = {
        carry_barrels = true,
        barrel_caves = true,
        barrel_lava = true,
        blue_potions = true,
        elemental_haste = true,
        elemental_heal = true,
        elemental_ice = true,
        gold_small = true,
        gold_medium = true,
        gold_large = true,
        keys_small = true,
    },
    drop_weights = {
        carry_barrels = 2,
        barrel_caves = 2,
        barrel_lava = 2,
        blue_potions = 4,
        elemental_haste = 1,
        elemental_heal = 2,
        elemental_ice = 2,
        gold_small = 1,
        gold_medium = 2,
        gold_large = 4,
        keys_small = 2,
    },
}

-- Weighted drop pool, rebuilt by update_drop_tables() from the enabled entries.
RandomUrns.gold_drops = {}

-- Rebuild the pool whenever the config changes.
function RandomUrns.update_drop_tables()
    local pool = {}

    for _, entry in ipairs(RandomUrns.drop_table) do
        if RandomUrns.CONFIG.drop_types[entry.id] then
            table.insert(pool, {
                path = entry.path,
                weight = RandomUrns.CONFIG.drop_weights[entry.id] or 1,
            })
        end
    end

    -- Ensure we always have at least one item to prevent errors
    if #pool == 0 then
        pool = { { path = "gameobjects/gold/pile_small", weight = 1 } }
    end

    RandomUrns.gold_drops = pool
end

RandomUrns.update_drop_tables()

-- Same inverse-weight roll as ColosseumStones: a weight of 1 is the most common
-- drop and 4 the rarest, each entry contributing 1/weight to the pool.
function RandomUrns.pick_weighted_drop()
    local total = 0
    for _, entry in ipairs(RandomUrns.gold_drops) do
        total = total + (1 / entry.weight)
    end

    local roll = math.random() * total
    local combined = 0
    for _, entry in ipairs(RandomUrns.gold_drops) do
        combined = combined + (1 / entry.weight)
        if roll <= combined then
            return entry.path
        end
    end

    return RandomUrns.gold_drops[#RandomUrns.gold_drops].path
end


Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "props/smashable_generic" then
        result.on_death_authorative = function (unit, is_local_hit, hit, component)
            if not _G.is_host_ducks_mods then
                return 
            end

            local unit_path = Unit.get_data(unit, "unit_path") or ""
            local big_prop = is_big_prop(unit_path)

            -- Big props roll on the big chance, everything else on the small chance.
            local enabled = big_prop and RandomUrns.CONFIG.big_props_enabled or RandomUrns.CONFIG.small_props_enabled
            local chance = big_prop and RandomUrns.CONFIG.drop_chance_big or RandomUrns.CONFIG.drop_chance_small
            if not enabled or math.random() > chance then
                return
            end

            local entity_spawner = FlowCallbacks.state_game.entity_spawner
            local drop = RandomUrns.pick_weighted_drop()
            local position = Unit.world_position(unit, 0)
            local rotation = Unit.world_rotation(unit, 0)

            if big_prop then
                local parent_id = EntityAux.go_id(unit)
                local dropped_unit = entity_spawner:spawn_entity(drop, position, rotation, parent_id)
                Unit.set_data(dropped_unit, "is_dropped", true)
                Unit.flow_event(dropped_unit, "on_dropped")
                NetworkUnitSynchronizer:add(dropped_unit)
            else
                entity_spawner:spawn_entity(drop, position, rotation)
            end
        end
    end

    if (path == "gameobjects/gold/urn" or
        path == "gameobjects/gold/goldrock" or
        path == "props/d01_caves/cart_smashable") then

        result.on_death_authorative = function (unit, is_local_hit, hit, component)
            if not _G.is_host_ducks_mods then
                return 
            end

            -- Urns, goldrocks and carts are big props, so they roll the big chance.
            if not RandomUrns.CONFIG.big_props_enabled or math.random() > RandomUrns.CONFIG.drop_chance_big then
                return
            end

            local entity_spawner = FlowCallbacks.state_game.entity_spawner
            local drop = RandomUrns.pick_weighted_drop()
            local position = Unit.world_position(unit, 0)
            local rotation = Unit.world_rotation(unit, 0)
            entity_spawner:spawn_entity(drop, position, rotation)
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)

