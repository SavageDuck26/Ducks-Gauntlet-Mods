-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: Summoners Configuration UI Module
-- =================================================================================================

local MOD_NAME = "SummonersUI"

-- Initialize Summoners global structure
Summoners = Summoners or {}
Summoners.loaded = Summoners.loaded or false

-- Saveable settings
Summoners.CONFIG = Summoners.CONFIG or {
    enabled = true,
    summoners = {
        cultist_sorcerer = {
            enabled = true,
            shadow_serpent_chance = 0.25,
            shield_spawner_chance = 0.25,
        },
        mummy_priest = {
            enabled = true,
            bloat_skeleton_chance = 0.33,
            bloat_necromancer_chance = 0.10,
        },
        grunt_shaman = {
            enabled = true,
            projectile_chance = 0.25,
        },
        skeleton_commander = {
            enabled = true,
            arrow_lob_chance = 1.00,
        },
        cultist_zealot = {
            enabled = true,
            death_spawn_chance = 1.00,
        },
    },
}

-- Function to sync summoners settings before saving
function Summoners.update_config()
    -- Config is now directly on Summoners.*, no sync needed
end

-- Function to load summoners settings
function Summoners.load_config()
    -- Config is now directly on Summoners.*, no sync needed
end

-- Summoner data for UI
local SUMMONER_DATA = {
    { 
        id = "cultist_sorcerer", 
        name = "Cultist Sorcerer", 
        settings = {
            { key = "shadow_serpent_chance", label = "Shadow Serpent Spawn", spawn = "Cultist Armor" },
            { key = "shield_spawner_chance", label = "Shield Spawner Spawn", spawn = "Demon Heavy" },
        }
    },
    { 
        id = "mummy_priest", 
        name = "Mummy Priest", 
        settings = {
            { key = "bloat_skeleton_chance", label = "Bloat Skeleton Spawn", spawn = "Skeleton Warrior" },
            { key = "bloat_necromancer_chance", label = "Bloat Necromancer Spawn", spawn = "Necromancer" },
        }
    },
    { 
        id = "grunt_shaman", 
        name = "Grunt Shaman", 
        settings = {
            { key = "projectile_chance", label = "Projectile Spawn", spawn = "Homing Skull" },
        }
    },
    { 
        id = "skeleton_commander", 
        name = "Skeleton Commander", 
        settings = {
            { key = "arrow_lob_chance", label = "Arrow Lob Spawn", spawn = "Lich" },
        }
    },
    { 
        id = "cultist_zealot", 
        name = "Cultist Zealot", 
        settings = {
            { key = "death_spawn_chance", label = "Death Spawn", spawn = "Demon Melee" },
        }
    },
}

-- Store reference to current config widget
local current_summoners_widget = nil

-- Function to create summoner config row
local function create_summoner_row(summoner_data, y_pos)
    local summoner_id = summoner_data.id
    
    -- Ensure summoner config exists with defaults
    if not Summoners.CONFIG.summoners[summoner_id] then
        Summoners.CONFIG.summoners[summoner_id] = {
            enabled = true,
        }
        for _, setting in ipairs(summoner_data.settings) do
            Summoners.CONFIG.summoners[summoner_id][setting.key] = 0.25
        end
    end
    
    local summoner_config = Summoners.CONFIG.summoners[summoner_id]
    
    local children = {
        -- Summoner name label
        {
            type = "label",
            text = summoner_data.name,
            font_size = 20,
            color = "yellow",
            size = {200, 40},
            text_align = "left"
        },
        -- Enable/Disable checkbox
        {
            checked = summoner_config.enabled,
            id = summoner_id .. "_enabled_checkbox",
            type = "checkbox",
            size = {40, 40},
            on = {
                clicked = function()
                    Summoners.CONFIG.summoners[summoner_id].enabled = not Summoners.CONFIG.summoners[summoner_id].enabled
                    Summoners.hide_config()
                    Summoners.show_config()
                end
            }
        },
    }
    
    return {
        layout = "horizontal",
        spacing = 10,
        type = "container",
        position = {"left + 30", y_pos},
        children = children
    }
end

-- Function to create setting row (slider for chance)
local function create_setting_row(summoner_id, setting, y_pos)
    local summoner_config = Summoners.CONFIG.summoners[summoner_id]
    local chance_value = summoner_config[setting.key] or 0.25
    
    local children = {
        -- Setting label
        {
            type = "label",
            text = "    " .. setting.label .. " (" .. setting.spawn .. "):",
            font_size = 16,
            color = "white",
            size = {400, 35},
            text_align = "left"
        },
        -- Chance slider
        {
            id = summoner_id .. "_" .. setting.key .. "_slider",
            type = "slider",
            inherit = "slider",
            min = 0,
            max = 1,
            value = chance_value,
            size = {300, 35},
            on = {
                changed = function(widget, value)
                    local rounded_value = math.floor(value * 100 + 0.5) / 100
                    Summoners.CONFIG.summoners[summoner_id][setting.key] = rounded_value
                    -- Update the percentage label
                    if current_summoners_widget then
                        local label_widget = current_summoners_widget:get(summoner_id .. "_" .. setting.key .. "_label")
                        if label_widget and label_widget.set_text then
                            label_widget:set_text(string.format("%.0f%%", rounded_value * 100))
                        end
                    end
                end
            }
        },
        -- Chance percentage label
        {
            id = summoner_id .. "_" .. setting.key .. "_label",
            type = "label",
            text = string.format("%.0f%%", chance_value * 100),
            font_size = 18,
            color = "white",
            size = {60, 35},
            text_align = "left"
        },
    }
    
    return {
        layout = "horizontal",
        spacing = 8,
        type = "container",
        position = {"left + 30", y_pos},
        children = children
    }
end

local function create_summoners_config_ui()
    local all_rows = {}
    local start_y = 130
    local current_y = start_y
    
    -- Create rows for each summoner
    for _, summoner_data in ipairs(SUMMONER_DATA) do
        -- Add summoner header row
        table.insert(all_rows, create_summoner_row(summoner_data, "top + " .. current_y))
        current_y = current_y + 40
        
        -- Add setting rows for this summoner
        for _, setting in ipairs(summoner_data.settings) do
            table.insert(all_rows, create_setting_row(summoner_data.id, setting, "top + " .. current_y))
            current_y = current_y + 35
        end
        
        -- Add spacing between summoners
        current_y = current_y + 10
    end
    
    -- Build main children array
    local main_children = {
        -- Title
        {
            id = "summoners_title",
            type = "label",
            text = "Summoners Configuration",
            font_size = 36,
            color = "white",
            position = {"center", "top + 30"},
            text_align = "center"
        },
        -- Enable/Disable all checkbox
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center", "top + 85"},
            children = {
                {
                    type = "label",
                    text = "Enable Summoners Mod:",
                    font_size = 24,
                    color = "white",
                    size = {260, 40}
                },
                {
                    checked = Summoners.CONFIG.enabled,
                    id = "summoners_enabled_checkbox",
                    type = "checkbox",
                    text = "Enabled",
                    color = "white",
                    font_size = 20,
                    size = {150, 40},
                    on = {
                        clicked = function()
                            Summoners.CONFIG.enabled = not Summoners.CONFIG.enabled
                            Summoners.hide_config()
                            Summoners.show_config()
                        end
                    }
                }
            }
        },
        -- Instructions
        {
            id = "instructions",
            type = "label",
            text = "Configure spawn chances for each summoner enemy. Checkbox enables/disables the enemy's summoning.",
            font_size = 18,
            color = "white",
            position = {"center", "bottom - 70"},
            text_align = "center"
        },
        -- Back button
        {
            id = "summoners_back_button",
            type = "button",
            text = "Back",
            font_size = 24,
            color = "white",
            position = {"center", "bottom - 10"},
            size = {200, 50},
            style = "button_standard",
            on = {
                clicked = function()
                    Summoners.hide_config()
                end
            }
        }
    }
    
    -- Add all rows
    for _, row in ipairs(all_rows) do
        table.insert(main_children, row)
    end
    
    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.7,
                bg_img = "black",
                id = "summoners_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {900, 700},
                type = "container",
                children = main_children
            }
        }
    }
end

function Summoners.show_config()
    if current_summoners_widget then
        return
    end
    
    current_summoners_widget = GUI:load_proto(create_summoners_config_ui())
    GUI:add_modal_widget(current_summoners_widget, GUI.MAIN_CONTROLLER)
end

function Summoners.hide_config()
    if not current_summoners_widget then
        return
    end
    
    GUI:remove_modal_widget(current_summoners_widget)
    GUI:destroy_widget(current_summoners_widget)
    current_summoners_widget = nil
end
