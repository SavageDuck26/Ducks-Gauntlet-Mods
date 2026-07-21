-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: RandomUrns Configuration UI Module
-- =================================================================================================

local MOD_NAME = "RandomUrnsUI"

-- Initialize global RandomUrns namespace (shared with script.lua)
RandomUrns = RandomUrns or {}

RandomUrns.loaded = RandomUrns.loaded or false

RandomUrns.gold_drops = RandomUrns.gold_drops or {}
RandomUrns.props_drops = RandomUrns.props_drops or {}
RandomUrns.explosive_drops = RandomUrns.explosive_drops or {}

-- Settings stored directly on RandomUrns
RandomUrns.CONFIG = RandomUrns.CONFIG or { drop_types = { carry_barrels = true, blue_potions = true, elemental_haste = true, elemental_heal = true }, normal_drops = true, old_drops = false, explosive_only_props = false, drop_chance = 0.33 }

local current_randomurns_config_widget = nil

-- Function to update the drop tables based on current config
function RandomUrns.update_drop_tables()
    RandomUrns.gold_drops = {}
    
    if RandomUrns.CONFIG.drop_types.carry_barrels then
        table.insert(RandomUrns.gold_drops, "gameobjects/carry/carry_barrel_crypt")
    end
    
    if RandomUrns.CONFIG.drop_types.blue_potions then
        table.insert(RandomUrns.gold_drops, "gameobjects/potions/potion_blue")
    end
    
    if RandomUrns.CONFIG.drop_types.elemental_haste then
        table.insert(RandomUrns.gold_drops, "gameobjects/carry/elemental_haste")
    end
    
    if RandomUrns.CONFIG.drop_types.elemental_heal then
        table.insert(RandomUrns.gold_drops, "gameobjects/carry/elemental_heal")
    end
    
    -- Ensure we always have at least one item to prevent errors
    if #RandomUrns.gold_drops == 0 then
        RandomUrns.gold_drops = {"gameobjects/gold/pile_small"}
    end
end

-- Initialize drop tables on load
RandomUrns.update_drop_tables()

-- Function to update radio button states (for when loading from config)
function RandomUrns.update_radio_buttons()
    if not current_randomurns_config_widget then
        return
    end
    
    local normal_radio = current_randomurns_config_widget:get("special_normal_radio")
    local explosive_radio = current_randomurns_config_widget:get("special_explosive_radio")
    local old_radio = current_randomurns_config_widget:get("special_old_drops_radio")
    
    if normal_radio then
        normal_radio:set_checked(RandomUrns.CONFIG.normal_drops)
    end
    
    if explosive_radio then
        explosive_radio:set_checked(RandomUrns.CONFIG.explosive_only_props)
    end

    if old_radio then
        old_radio:set_checked(RandomUrns.CONFIG.old_drops)
    end
end

-- Function to sync from config structure (used when loading from JSON)
function RandomUrns.update_from_config()
    -- Update the drop tables
    RandomUrns.update_drop_tables()
    
    -- Update UI if it's open
    RandomUrns.update_radio_buttons()
end

function RandomUrns.load_config()
    RandomUrns.update_drop_tables()
end

local function create_randomurns_config_ui()
    return {
        css = "gui/default_css",
        id = "randomurns_config_ui",
        position = "center",
        top_priority = 250,
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.8,
                bg_img = "black",
                id = "randomurns_config_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1000, 600},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "randomurns_config_title",
                        type = "label",
                        text = "RandomUrns Config",
                        font_size = 32,
                        color = "white",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Special Props Section
                    {
                        id = "special_props_title",
                        type = "label",
                        text = "Regular Props (Boxes, Torches, Spider Eggs):",
                        font_size = 22,
                        color = "yellow",
                        position = {"center + 210", "top + 80"},
                        text_align = "center"
                    },
                    -- Special props mode selection (radio buttons)
                    {
                        layout = "horizontal",
                        spacing = 30,
                        type = "container",
                        position = {"center + 210", "top + 110"},
                        children = {
                            {
                                checked = (RandomUrns.CONFIG.normal_drops),
                                id = "special_normal_radio",
                                type = "radiobutton",
                                text = "Normal Drops",
                                size = {150, 40},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.normal_drops = true
                                        RandomUrns.CONFIG.explosive_only_props = false
                                        RandomUrns.CONFIG.old_drops = false
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            },
                            {
                                checked = (RandomUrns.CONFIG.explosive_only_props),
                                id = "special_explosive_radio",
                                type = "radiobutton",
                                text = "Explosive Only",
                                color = "red",
                                size = {150, 40},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.explosive_only_props = true
                                        RandomUrns.CONFIG.normal_drops = false
                                        RandomUrns.CONFIG.old_drops = false
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            },
                            -- ===================================================================================
                            {
                                checked = (RandomUrns.CONFIG.old_drops),
                                id = "special_old_drops_radio",
                                type = "radiobutton",
                                text = "Legacy Drops",
                                size = {150, 40},
                                font_size = 18,
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.old_drops = true
                                        RandomUrns.CONFIG.normal_drops = false
                                        RandomUrns.CONFIG.explosive_only_props = false
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            }
                        }
                    },
                    -- Prop Drop Chance label (above slider)
                    {
                        id = "urns_dropchance_label",
                        type = "label",
                        text = "Prop Drop Chance:",
                        font_size = 24,
                        color = "yellow",
                        position = {"left + 60", "top + 70"},
                        text_align = "left"
                    },
                    -- Drop Chance Slider Section (top-left)
                    {
                        layout = "horizontal",
                        spacing = 15,
                        type = "container",
                        position = {"left + 25", "top + 100"},
                        children = {
                            {
                                id = "urns_dropchance_slider",
                                type = "slider",
                                inherit = "slider",
                                min = 0,
                                max = 1,
                                value = RandomUrns.CONFIG.drop_chance or 0.33,
                                size = {315, 50},
                                on = {
                                    changed = function(widget, value)
                                        -- Round to hundredths place
                                        local rounded_value = math.floor(value * 100 + 0.5) / 100
                                        RandomUrns.CONFIG.drop_chance = rounded_value
                                        local value_label = current_randomurns_config_widget and current_randomurns_config_widget:get("urns_dropchance_value")
                                        if value_label and value_label.set_text then
                                            value_label:set_text(string.format("%d%%", math.floor((rounded_value or 0) * 100 + 0.5)))
                                        end
                                    end
                                }
                            },
                            {
                                id = "urns_dropchance_value",
                                type = "label",
                                text = string.format("%d%%", math.floor(((RandomUrns.CONFIG.drop_chance or 0.33) * 100) + 0.5)),
                                font_size = 24,
                                color = "white",
                                size = {90, 55},
                                text_align = "left"
                            }
                        }
                    },
                    -- Regular Drops Section
                    {
                        id = "regular_drops_title",
                        type = "label",
                        text = "Regular Urns & Goldrocks Drops:",
                        font_size = 24,
                        color = "yellow",
                        position = {"center", "top + 200"},
                        text_align = "center"
                    },
                    -- Carry Barrels checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 230"},
                        children = {
                            {
                                checked = RandomUrns.CONFIG.drop_types.carry_barrels,
                                id = "carry_barrels_checkbox",
                                type = "checkbox",
                                size = {40, 40},
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.drop_types.carry_barrels = not RandomUrns.CONFIG.drop_types.carry_barrels
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Explosive Barrels",
                                font_size = 20,
                                color = "white",
                                size = {120, 25}
                            }
                        }
                    },
                    -- Blue Potions checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 265"},
                        children = {
                            {
                                checked = RandomUrns.CONFIG.drop_types.blue_potions,
                                id = "blue_potions_checkbox",
                                type = "checkbox",
                                size = {40, 40},
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.drop_types.blue_potions = not RandomUrns.CONFIG.drop_types.blue_potions
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Potions",
                                font_size = 20,
                                color = "white",
                                size = {120, 25}
                            }
                        }
                    },
                    -- Elemental Haste checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 300"},
                        children = {
                            {
                                checked = RandomUrns.CONFIG.drop_types.elemental_haste,
                                id = "elemental_haste_checkbox",
                                type = "checkbox",
                                size = {40, 40},
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.drop_types.elemental_haste = not RandomUrns.CONFIG.drop_types.elemental_haste
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Elemental Haste",
                                font_size = 20,
                                color = "white",
                                size = {120, 25}
                            }
                        }
                    },
                    -- Elemental Heal checkbox
                    {
                        layout = "horizontal",
                        spacing = 10,
                        type = "container",
                        position = {"center", "top + 335"},
                        children = {
                            {
                                checked = RandomUrns.CONFIG.drop_types.elemental_heal,
                                id = "elemental_heal_checkbox",
                                type = "checkbox",
                                size = {40, 40},
                                on = {
                                    clicked = function()
                                        RandomUrns.CONFIG.drop_types.elemental_heal = not RandomUrns.CONFIG.drop_types.elemental_heal
                                        RandomUrns.update_drop_tables()
                                        RandomUrns.hide_config()
                                        RandomUrns.show_config()
                                    end
                                }
                            },
                            {
                                text_align = "left",
                                type = "label",
                                text = "Elemental Heal",
                                font_size = 20,
                                color = "white",
                                size = {120, 25}
                            }
                        }
                    },
                    -- Instructions
                    {
                        id = "instructions",
                        type = "label",
                        text = "Explosive Only makes all Regular Props drop Explosive Barrels.",
                        font_size = 24,
                        color = "white",
                        position = {"center", "top + 420"},
                        text_align = "center"
                    },
                    {
                        id = "instructions",
                        type = "label",
                        text = "Prop Drop Chance is for the Regular Props Normal Drops.",
                        font_size = 24,
                        color = "white",
                        position = {"center", "top + 450"},
                        text_align = "center"
                    },
                    -- Back button
                    {
                        id = "randomurns_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 20,
                        color = "white",
                        position = {"center", "bottom - 40"},
                        size = {200, 45},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                RandomUrns.hide_config()
                            end
                        }
                    }
                }
            }
        }
    }
end

-- Function to show config overlay
function RandomUrns.show_config()
    if current_randomurns_config_widget then
        return
    end
    if not RandomUrns.loaded then
        return -- Base mod not loaded
    end
    
    current_randomurns_config_widget = GUI:load_proto(create_randomurns_config_ui())
    GUI:add_modal_widget(current_randomurns_config_widget, GUI.MAIN_CONTROLLER)
    -- Initialize the drop chance value label to reflect the current setting
    local value_label = current_randomurns_config_widget and current_randomurns_config_widget:get("urns_dropchance_value")
    if value_label and value_label.set_text then
        value_label:set_text(string.format("%d%%", math.floor(((RandomUrns.CONFIG.drop_chance or 0.33) * 100) + 0.5)))
    end
end

-- Function to hide config overlay
function RandomUrns.hide_config()
    if not current_randomurns_config_widget then
        return
    end
    
    GUI:remove_modal_widget(current_randomurns_config_widget)
    GUI:destroy_widget(current_randomurns_config_widget)
    current_randomurns_config_widget = nil
end
