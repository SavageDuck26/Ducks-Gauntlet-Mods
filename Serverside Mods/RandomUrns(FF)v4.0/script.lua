-- =================================================================================================
-- Author: SavageDuck26
-- Version: 4.0
-- Purpose: Makes urns and goldrocks drops random things (Barrels, skullcoins, potions, stones, keys.)
-- =================================================================================================

-- LAVA CRATES CANNOT BE CHANGED. THEY INSTA-CRASH THE GAME IF MODIFIED.
-- This note above should be correct. However it's not. I don't know why, for some reason now it works.
-- I have learned that the lava_metalbox uses the goldrock as a base, that's why it works now.

local MOD_NAME = "RandomUrns"

RandomUrns = RandomUrns or {}

RandomUrns.loaded = true

-- Saveable settings
RandomUrns.CONFIG = RandomUrns.CONFIG or {
    drop_chance = 0.33,
    drop_types = {
        carry_barrels = true,
        blue_potions = true,
        elemental_haste = true,
        elemental_heal = true,
    },
    normal_drops = true,
    old_drops = false,
    explosive_only_props = false,
}

RandomUrns.current_config_widget = RandomUrns.current_config_widget or nil

RandomUrns.gold_drops = {
    "gameobjects/carry/carry_barrel_crypt",
    "gameobjects/potions/potion_blue",
    "gameobjects/carry/elemental_haste",
    "gameobjects/carry/elemental_heal",
}

RandomUrns.CONFIG.old_drops_list = {
    "gameobjects/carry/carry_barrel_crypt",
    "gameobjects/potions/potion_blue",
    "gameobjects/keys/small",
    "gameobjects/carry/elemental_haste",
    "gameobjects/carry/elemental_heal",
}

RandomUrns.props_drops = {
    "gameobjects/keys/small", -- Keep chance low
    -- ==============================
    "gameobjects/gold/pile_small", -- 1
    "gameobjects/gold/pile_small", -- 2
    "gameobjects/gold/pile_small", -- 3
    "gameobjects/gold/pile_small", -- 4
    "gameobjects/gold/pile_small", -- 5
    "gameobjects/gold/pile_small", -- 6
    "gameobjects/gold/pile_small", -- 7
    "gameobjects/gold/pile_small", -- 8
    "gameobjects/gold/pile_small", -- 9
    "gameobjects/gold/pile_small", -- 10
    "gameobjects/gold/pile_small", -- 11
    "gameobjects/gold/pile_small", -- 12
    -- ==============================
    "gameobjects/gold/pile_medium", -- 1
    "gameobjects/gold/pile_medium", -- 2
    "gameobjects/gold/pile_medium", -- 3
    "gameobjects/gold/pile_medium", -- 4
    "gameobjects/gold/pile_medium", -- 5
    -- ==============================
    "gameobjects/gold/pile_large", -- 1
}

RandomUrns.explosive_drops = {
    "gameobjects/carry/carry_barrel_crypt",
    "gameobjects/carry/carry_barrel_caves",
    "gameobjects/carry/carry_barrel_lava",
}

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "props/smashable_generic" then
        result.on_death_authorative = function (unit, is_local_hit, hit, component)
            if not _G.is_host_ducks_mods then
                return 
            end

            if RandomUrns.CONFIG.old_drops then
                return
            end
            
            local unit_path = Unit.get_data(unit, "unit_path") or ""
        
            if string.match(unit_path, "props/d01_lava/lava_torture_device_01") or
               string.match(unit_path, "props/d01_lava/lava_weapon_rack_01") or
               string.match(unit_path, "props/d01_lava/vase") or
               -- ======================================================================
               string.match(unit_path, "props/d01_caves/spideregg_01") or
               -- ======================================================================
               string.match(unit_path, "props/d01_common/box_small_01") or
               string.match(unit_path, "props/d01_common/barrel_01") or
               string.match(unit_path, "props/d01_common/barrel_01_rotten") then
                
                if math.random() <= RandomUrns.CONFIG.drop_chance then -- Chance to drop something
                    local drops = RandomUrns.gold_drops

                    local entity_spawner = FlowCallbacks.state_game.entity_spawner
                    local drop = drops[math.random(#drops)]
                    local position = Unit.world_position(unit, 0)
                    local rotation = Unit.world_rotation(unit, 0)
                    local parent_id = EntityAux.go_id(unit)
                    local dropped_unit = entity_spawner:spawn_entity(drop, position, rotation, parent_id)
                    Unit.set_data(dropped_unit, "is_dropped", true)
                    Unit.flow_event(dropped_unit, "on_dropped")
                    NetworkUnitSynchronizer:add(dropped_unit)
                end
                -- =====================================================================
            else
                local drops = RandomUrns.props_drops

                if RandomUrns.CONFIG.explosive_only_props then
                    drops = RandomUrns.explosive_drops
                else
                    drops = RandomUrns.props_drops
                end

                local entity_spawner = FlowCallbacks.state_game.entity_spawner
                local drop = drops[math.random(#drops)]
                local position = Unit.world_position(unit, 0)
                local rotation = Unit.world_rotation(unit, 0)
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
            
            local drops = RandomUrns.gold_drops
            if RandomUrns.CONFIG.old_drops then
                drops = RandomUrns.CONFIG.old_drops_list
            end

            local entity_spawner = FlowCallbacks.state_game.entity_spawner
            local drop = drops[math.random(#drops)]
            local position = Unit.world_position(unit, 0)
            local rotation = Unit.world_rotation(unit, 0)
            entity_spawner:spawn_entity(drop, position, rotation)
        end
    end

    return result
end)