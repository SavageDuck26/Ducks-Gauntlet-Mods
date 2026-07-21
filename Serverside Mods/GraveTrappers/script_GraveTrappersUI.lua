local MOD_NAME = "GraveTrappersUI"

-- Ensure GraveTrappers global exists
GraveTrappers = GraveTrappers or {}

-- Initialize config if not present (in case UI loads before main script)
if not GraveTrappers.CONFIG.enemies then
    GraveTrappers.CONFIG.enabled = true
    GraveTrappers.CONFIG.confusion_duration = 4 -- Default confusion effect timer in seconds
    GraveTrappers.CONFIG.affect_enemies = false -- Whether poison/shockwave effects affect enemies
    GraveTrappers.CONFIG.enemies = {
        skeleton_defender = { trap = "spikeplate", chance = 0.04 },
        mummy_giant = { trap = "spikeplate", chance = 0.04 },
        mummy_priest = { trap = "spikeplate", chance = 0.04 },
        skeleton_commander = { trap = "spikeplate", chance = 0.04 },
        grunt_shaman = { trap = "spinner", chance = 0.04 },
        orc_juggernaut = { trap = "spinner", chance = 0.50 },
        spider_warrior = { trap = "spinner", chance = 0.50 },
        cultist_sorcerer = { trap = "lavacolumn", chance = 0.12 },
        demon_ranged = { trap = "lavacolumn", chance = 0.50 },
    }
end

function GraveTrappers.toggle()
    GraveTrappers.CONFIG.enabled = not GraveTrappers.CONFIG.enabled
end

-- Enemy configuration data
local ENEMY_DATA = {
    { id = "skeleton_defender", name = "Skeleton Defender", biome = "crypt" },
    { id = "mummy_giant", name = "Mummy Giant", biome = "crypt" },
    { id = "mummy_priest", name = "Mummy Priest", biome = "crypt" },
    { id = "skeleton_commander", name = "Skeleton Commander", biome = "crypt" },
    { id = "grunt_shaman", name = "Grunt Shaman", biome = "caves" },
    { id = "orc_juggernaut", name = "Orc Juggernaut", biome = "caves" },
    { id = "spider_warrior", name = "Spider Warrior", biome = "caves" },
    { id = "cultist_sorcerer", name = "Cultist Sorcerer", biome = "lava" },
    { id = "demon_ranged", name = "Demon Gargoyle", biome = "lava" },
}

local TRAP_OPTIONS = {
    crypt = {
        { id = "spikeplate", name = "Spike Plate", path = "gameobjects/traps/spikeplate_1c_1c" },
        { id = "floorspears", name = "Floor Spears", path = "gameobjects/traps/trap_floor_spears_1c_1c" },
    },
    caves = {
        { id = "spikeplate", name = "Spike Plate", path = "gameobjects/traps/spikeplate_1c_1c" },
        { id = "spinner", name = "Spinner Blade", path = "gameobjects/traps/trap_spinner_4c_1blades" },
    },
    lava = {
        { id = "floorblade", name = "Floor Blade", path = "gameobjects/traps/trap_lava_floor_blades_4c" },
        { id = "lavacolumn", name = "Lava Column", path = "gameobjects/traps/lavacolumn" },
    }
}

-- Get trap options for a biome
local function get_trap_options(biome)
    return TRAP_OPTIONS[biome] or TRAP_OPTIONS.caves
end

-- Get trap path from trap ID and biome
function GraveTrappers.get_trap_path(trap_id, biome)
    local options = get_trap_options(biome)
    for _, opt in ipairs(options) do
        if opt.id == trap_id then
            return opt.path
        end
    end
    return nil
end

-- Function to sync gravetrappers settings before saving
function GraveTrappers.update_config()
    -- Config is already stored directly on GraveTrappers, nothing to sync
end

-- Function to load gravetrappers settings
function GraveTrappers.load_config()
    -- Ensure enemies table exists with all enemies
    if not GraveTrappers.CONFIG.enemies then
        GraveTrappers.CONFIG.enemies = {
            skeleton_defender = { trap = "spikeplate", chance = 0.04 },
            mummy_giant = { trap = "spikeplate", chance = 0.04 },
            mummy_priest = { trap = "spikeplate", chance = 0.04 },
            skeleton_commander = { trap = "spikeplate", chance = 0.04 },
            grunt_shaman = { trap = "spinner", chance = 0.04 },
            orc_juggernaut = { trap = "spinner", chance = 0.50 },
            spider_warrior = { trap = "spinner", chance = 0.50 },
            cultist_sorcerer = { trap = "lavacolumn", chance = 0.12 },
            demon_ranged = { trap = "lavacolumn", chance = 0.50 },
        }
    end
end

-- Current enemy being configured
local current_enemy_index = 1
local current_gravetrappers_widget = nil

-- Function to create enemy config row
local function create_enemy_row(enemy_data, y_pos)
    local enemy_id = enemy_data.id
    
    -- Ensure enemy config exists with defaults
    if not GraveTrappers.CONFIG.enemies[enemy_id] then
        local default_traps = {
            crypt = "spikeplate",
            caves = "spinner",
            lava = "lavacolumn"
        }
        GraveTrappers.CONFIG.enemies[enemy_id] = {
            trap = default_traps[enemy_data.biome] or "spikeplate",
            chance = 0.04
        }
    end
    
    local enemy_config = GraveTrappers.CONFIG.enemies[enemy_id]
    local trap_options = get_trap_options(enemy_data.biome)
    
    local children = {
        -- Enemy name label
        {
            type = "label",
            text = enemy_data.name,
            font_size = 18,
            color = "white",
            size = {240, 40},
            text_align = "left"
        }
    }
    
    -- Add trap radio buttons
    for i, trap_opt in ipairs(trap_options) do
        table.insert(children, {
            checked = (enemy_config.trap == trap_opt.id),
            id = enemy_id .. "_trap_" .. trap_opt.id,
            type = "radiobutton",
            text = trap_opt.name,
            size = {140, 40},
            font_size = 16,
            on = {
                clicked = function()
                    GraveTrappers.CONFIG.enemies[enemy_id].trap = trap_opt.id
                    GraveTrappers.hide_config()
                    GraveTrappers.show_config()
                end
            }
        })
    end
    
    -- Spacing
    table.insert(children, {
        type = "label",
        text = "|",
        font_size = 18,
        color = "yellow",
        size = {30, 40}
    })
    
    -- Chance label
    table.insert(children, {
        type = "label",
        text = "Drop Chance:",
        font_size = 16,
        color = "white",
        size = {120, 40}
    })
    
    -- Chance slider
    table.insert(children, {
        id = enemy_id .. "_chance_slider",
        type = "slider",
        inherit = "slider",
        min = 0,
        max = 1,
        value = enemy_config.chance or 0.04,
        size = {300, 40},
        on = {
            changed = function(widget, value)
                -- Round to hundredths place
                local rounded_value = math.floor(value * 100 + 0.5) / 100
                GraveTrappers.CONFIG.enemies[enemy_id].chance = rounded_value
                -- Update the percentage label
                local current_widget = current_gravetrappers_widget
                if current_widget then
                    local label_widget = current_widget:get(enemy_id .. "_chance_label")
                    if label_widget and label_widget.set_text then
                        label_widget:set_text(string.format("%.0f%%", rounded_value * 100))
                    end
                end
            end
        }
    })
    
    -- Chance percentage label
    table.insert(children, {
        id = enemy_id .. "_chance_label",
        type = "label",
        text = string.format("%.0f%%", (enemy_config.chance or 0.04) * 100),
        font_size = 18,
        color = "white",
        size = {60, 40},
        text_align = "left"
    })
    
    return {
        layout = "horizontal",
        spacing = 8,
        type = "container",
        position = {"left + 30", y_pos},
        children = children
    }
end

local function create_gravetrappers_config_ui()
    local enemy_rows = {}
    local start_y = 180
    
    -- Create header
    local header_children = {
        {
            type = "label",
            text = "Enemy",
            font_size = 20,
            color = "yellow",
            size = {240, 40},
            text_align = "left"
        },
        {
            type = "label",
            text = "Trap Type",
            font_size = 20,
            color = "yellow",
            size = {300, 40},
            text_align = "center"
        },
        {
            type = "label",
            text = "Drop Chance (0% - 100%)",
            font_size = 20,
            color = "yellow",
            size = {500, 40},
            text_align = "center"
        }
    }
    
    local header = {
        layout = "horizontal",
        spacing = 8,
        type = "container",
        position = {"left + 30", "top + 140"},
        children = header_children
    }
    
    -- Create enemy rows
    for i, enemy_data in ipairs(ENEMY_DATA) do
        table.insert(enemy_rows, create_enemy_row(enemy_data, "top + " .. (start_y + (i-1) * 50)))
    end
    
    -- Build main children array
    local main_children = {
        -- Title
        {
            id = "gravetrappers_title",
            type = "label",
            text = "GraveTrappers Configuration",
            font_size = 36,
            color = "white",
            position = {"center", "top + 30"},
            text_align = "center"
        },
        -- Enable/Disable checkbox
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"left + 30", "top + 75"},
            children = {
                {
                    type = "label",
                    text = "Enable GraveTrappers:",
                    font_size = 22,
                    color = "white",
                    size = {220, 40}
                },
                {
                    checked = GraveTrappers.CONFIG.enabled,
                    id = "gravetrappers_enabled_checkbox",
                    type = "checkbox",
                    text = "Enabled",
                    color = "white",
                    font_size = 18,
                    size = {120, 40},
                    on = {
                        clicked = function()
                            GraveTrappers.toggle()
                            GraveTrappers.hide_config()
                            GraveTrappers.show_config()
                        end
                    }
                }
            }
        },
        -- Confusion Duration slider
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"center", "top + 75"},
            children = {
                {
                    type = "label",
                    text = "Confusion Duration:",
                    font_size = 22,
                    color = "white",
                    size = {200, 40}
                },
                {
                    id = "confusion_duration_slider",
                    type = "slider",
                    inherit = "slider",
                    min = 1,
                    max = 30,
                    value = GraveTrappers.CONFIG.confusion_duration or 4,
                    size = {200, 40},
                    on = {
                        changed = function(widget, value)
                            local rounded_value = math.floor(value + 0.5)
                            GraveTrappers.CONFIG.confusion_duration = rounded_value
                            -- Update the duration label
                            if current_gravetrappers_widget then
                                local label_widget = current_gravetrappers_widget:get("confusion_duration_label")
                                if label_widget and label_widget.set_text then
                                    label_widget:set_text(string.format("%ds", rounded_value))
                                end
                            end
                        end
                    }
                },
                {
                    id = "confusion_duration_label",
                    type = "label",
                    text = string.format("%ds", GraveTrappers.CONFIG.confusion_duration or 4),
                    font_size = 22,
                    color = "white",
                    size = {50, 40},
                    text_align = "left"
                }
            }
        },
        -- Affect Enemies checkbox
        {
            layout = "horizontal",
            spacing = 10,
            type = "container",
            position = {"right - 50", "top + 75"},
            children = {
                {
                    type = "label",
                    text = "Elementals Affect Enemies:",
                    font_size = 22,
                    color = "white",
                    size = {270, 40}
                },
                {
                    checked = GraveTrappers.CONFIG.affect_enemies or false,
                    id = "affect_enemies_checkbox",
                    type = "checkbox",
                    size = {40, 40},
                    on = {
                        clicked = function()
                            GraveTrappers.CONFIG.affect_enemies = not GraveTrappers.CONFIG.affect_enemies
                            GraveTrappers.hide_config()
                            GraveTrappers.show_config()
                        end
                    }
                }
            }
        },
        -- Header
        header,
        -- Instructions
        {
            id = "instructions",
            type = "label",
            text = "Configure trap drops for each enemy. Boss enemies and spawners always drop elementals.",
            font_size = 20,
            color = "white",
            position = {"center", "bottom - 80"},
            text_align = "center"
        },
        -- Back button
        {
            id = "gravetrappers_back_button",
            type = "button",
            text = "Back",
            font_size = 24,
            color = "white",
            position = {"center", "bottom - 30"},
            size = {200, 50},
            style = "button_standard",
            on = {
                clicked = function()
                    GraveTrappers.hide_config()
                end
            }
        }
    }
    
    -- Add all enemy rows
    for _, row in ipairs(enemy_rows) do
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
                id = "gravetrappers_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main config container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1200, 850},
                type = "container",
                children = main_children
            }
        }
    }
end

function GraveTrappers.show_config()
    if current_gravetrappers_widget then
        return
    end
    
    current_gravetrappers_widget = GUI:load_proto(create_gravetrappers_config_ui())
    GUI:add_modal_widget(current_gravetrappers_widget, GUI.MAIN_CONTROLLER)
end

function GraveTrappers.hide_config()
    if not current_gravetrappers_widget then
        return
    end
    
    GUI:remove_modal_widget(current_gravetrappers_widget)
    GUI:destroy_widget(current_gravetrappers_widget)
    current_gravetrappers_widget = nil
end
