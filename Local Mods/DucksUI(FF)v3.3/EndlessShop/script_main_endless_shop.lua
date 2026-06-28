-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: EndlessShopItems Configuration UI Module
-- =================================================================================================

local MOD_NAME = "EndlessShopItemsUI"

_G.chaos_config = _G.chaos_config or {}
_G.endlessshop_config = _G.endlessshop_config or {}

_G.EndlessShopItems = {
	{id = "article_turkey", name = "Turkey", enabled = true},
	{id = "article_ham", name = "Ham", enabled = true},
	{id = "article_potion", name = "Potion", enabled = true},
	{id = "article_skullcoin", name = "Skullcoin", enabled = true},
}

_G.endlessshop_config.shop_items = _G.endlessshop_config.shop_items or {
    article_turkey = true,
    article_ham = true,
    article_potion = true,
    article_skullcoin = true
}

_G.endlessshop_config.dead_broke = _G.endlessshop_config.dead_broke or false

function update_endlessshop_from_config()
    for i, item in ipairs(_G.EndlessShopItems) do
        if _G.endlessshop_config.shop_items[item.id] ~= nil then
            item.enabled = _G.endlessshop_config.shop_items[item.id]
        end
    end
end

function update_endlessshop_config()
    for _, item in ipairs(_G.EndlessShopItems) do
        _G.endlessshop_config.shop_items[item.id] = item.enabled
    end
end

update_endlessshop_config()

local function get_enabled_shop_items()
	local enabled_items = {}
	for _, item in ipairs(_G.EndlessShopItems) do
		if item.enabled then
			table.insert(enabled_items, item.id)
		end
	end
	return enabled_items
end

local current_config_widget = nil

-- Function to toggle item enabled state
local function toggle_shop_item(index)
    if _G.EndlessShopItems and _G.EndlessShopItems[index] then
        _G.EndlessShopItems[index].enabled = not _G.EndlessShopItems[index].enabled
        
        update_endlessshop_config()
        
        if current_config_widget then
            local checkbox_id = "shop_item_" .. index
            local checkbox_widget = current_config_widget:get(checkbox_id)
            if checkbox_widget then
                checkbox_widget:set_checked(_G.EndlessShopItems[index].enabled)
            end
        end
    end
end

local function toggle_price_rise()
    _G.endlessshop_config.dead_broke = not _G.endlessshop_config.dead_broke

    if current_config_widget then
        local checkbox_widget = current_config_widget:get("shop_price_rise")
        if checkbox_widget then
            checkbox_widget:set_checked(_G.endlessshop_config.dead_broke)
        end
    end
end

local function create_config_overlay_ui()
    local children = {
        -- Semi-transparent background
        {
            alpha = 0.8,
            bg_img = "black",
            id = "config_background",
            position = {"center", "top"},
            size = {"100%", "100%"}
        },
        -- Main config container
        {
            bg_img = "menu_standard_background_stone",
            position = {"center", "center"},
            size = {600, 400},
            type = "container",
            children = {
                -- Title
                {
                    id = "config_title",
                    type = "label",
                    text = "EndlessShop Config",
                    font_size = 32,
                    color = "white",
                    position = {"center", "top + 30"},
                    text_align = "center"
                },
                -- Instructions
                {
                    id = "instructions",
                    type = "label",
                    text = "Select which items can appear in the endless shop:",
                    font_size = 22,
                    color = "white",
                    position = {"center", "top + 80"},
                    text_align = "center"
                },
                -- Back button
                {
                    id = "back_button",
                    type = "button",
                    text = "Back",
                    font_size = 24,
                    color = "white",
                    position = {"center", "bottom - 30"},
                    size = {200, 50},
                    style = "button_standard",
                    on = {
                        clicked = function()
                            hide_endlessshop_config()
                        end
                    }
                }
            }
        }
    }

    table.insert(children[2].children, 3, {
        layout = "horizontal",
        spacing = 10,
        type = "container",
        position = {"center + 110", "top + 280"},
        children = {
            {
                checked = _G.endlessshop_config.dead_broke,
                id = "shop_dead_broke",
                type = "checkbox",
                size = {30, 30},
                on = {
                    clicked = function()
                        toggle_price_rise()
                    end
                }
            },
            {
                text_align = "left",
                type = "label",
                text = "Dead Broke",
                font_size = 20,
                color = "white",
                size = {420, 30}
            }
        }
    })

    if _G.EndlessShopItems then
        local y_offset = 120
        for i, item in ipairs(_G.EndlessShopItems) do
            table.insert(children[2].children, {
                layout = "horizontal",
                spacing = 10,
                type = "container",
                position = {"center", "top + " .. (y_offset + (i - 1) * 40)},
                children = {
                    {
                        checked = item.enabled,
                        id = "shop_item_" .. i,
                        type = "checkbox",
                        size = {30, 30},
                        on = {
                            clicked = function()
                                toggle_shop_item(i)
                            end
                        }
                    },
                    {
                        text_align = "left",
                        type = "label",
                        text = item.name,
                        font_size = 20,
                        color = "white",
                        size = {200, 30}
                    }
                }
            })
        end
    end

    return {
        css = "gui/default_css",
        id = "endlessshop_config_overlay_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = children
    }
end

function show_endlessshop_config()
    if current_config_widget then
        return -- Already showing
    end    
    current_config_widget = GUI:load_proto(create_config_overlay_ui())
    
    GUI:add_modal_widget(current_config_widget, GUI.MAIN_CONTROLLER)    
end

function hide_endlessshop_config()
    if not current_config_widget then
        return -- Nothing to hide
    end
        
    GUI:remove_modal_widget(current_config_widget)
    
    GUI:destroy_widget(current_config_widget)
    current_config_widget = nil
end

_G.show_endlessshop_config = show_endlessshop_config

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    if path == "gameobjects/shop/article_random" and result then
        result.on_entity_registered = function (unit)
            if EntityAux.owned(unit) then
                local entity_spawner = FlowCallbacks.state_game.entity_spawner
                local enabled_items = get_enabled_shop_items()
                
                if #enabled_items == 0 then
                    enabled_items = {"article_turkey", "article_ham", "article_potion", "article_skullcoin"}
                end
                
                local article_index = math.random(#enabled_items)
                local entity = entity_spawner:spawn_entity(enabled_items[article_index], Unit.world_position(unit, 0), Unit.world_rotation(unit, 0))

                NetworkUnitSynchronizer:add(entity)
                entity_spawner:despawn_entity(unit, false)
            end
        end
    end

    -- I know this code sucks but it works.
    if path == "gameobjects/shop/article_potion" and result then
        if result.cost then
            if _G.chaos_config.mode == "limbo" and _G.endlessshop_config.dead_broke == true then
                result.cost = 2500 * 4
            elseif _G.chaos_config.mode == "hell" and _G.endlessshop_config.dead_broke == true then
                result.cost = 2500 * 3
            elseif _G.endlessshop_config.dead_broke == true and _G.chaos_config.mode ~= "limbo" and _G.chaos_config.mode ~= "hell" then
                result.cost = 2500 * 2
            else
                result.cost = 2500
            end
        end
    end

    if path == "gameobjects/shop/article_skullcoin" and result then
        if result.cost then
            if _G.chaos_config.mode == "limbo" and _G.endlessshop_config.dead_broke == true then
                result.cost = 2500 * 4
            elseif _G.chaos_config.mode == "hell" and _G.endlessshop_config.dead_broke == true then
                result.cost = 2500 * 3
            elseif _G.endlessshop_config.dead_broke == true and _G.chaos_config.mode ~= "limbo" and _G.chaos_config.mode ~= "hell" then
                result.cost = 2500 * 2
            else
                result.cost = 2500
            end
        end
    end

    if path == "gameobjects/shop/article_ham" and result then
        if result.cost then
            if _G.chaos_config.mode == "limbo" and _G.endlessshop_config.dead_broke == true then
                result.cost = 500 * 4
            elseif _G.chaos_config.mode == "hell" and _G.endlessshop_config.dead_broke == true then
                result.cost = 500 * 3
            elseif _G.endlessshop_config.dead_broke == true and _G.chaos_config.mode ~= "limbo" and _G.chaos_config.mode ~= "hell" then
                result.cost = 500 * 2
            else
                result.cost = 500
            end
        end
    end

    if path == "gameobjects/shop/article_turkey" and result then
        if result.cost then
            if _G.chaos_config.mode == "limbo" and _G.endlessshop_config.dead_broke == true then
                result.cost = 1000 * 4
            elseif _G.chaos_config.mode == "hell" and _G.endlessshop_config.dead_broke == true then
                result.cost = 1000 * 3
            elseif _G.endlessshop_config.dead_broke == true and _G.chaos_config.mode ~= "limbo" and _G.chaos_config.mode ~= "hell" then
                result.cost = 1000 * 2
            else
                result.cost = 1000
            end
        end
    end
    return result
end)