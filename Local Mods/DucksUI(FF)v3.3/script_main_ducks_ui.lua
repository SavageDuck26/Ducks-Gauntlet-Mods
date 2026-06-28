-- =================================================================================================
-- Author: SavageDuck26
-- Version: 3.3
-- Purpose: Main mod menu overlay system
-- =================================================================================================

local MOD_NAME = "DucksUI"

-- Initialize DucksUI global namespace
DucksUI = DucksUI or {}
DucksUI.loaded = true

-- List of mod namespaces that use the CONFIG pattern
local REGISTERED_MODS = {
    "Berserkers",
    "ChaosMode",
    "ColosseumStones",
    "DialogueFrequency",
    "GraveTrappers",
    "Knossos",
    "MeteorStorm",
    "MoreCrowns",
    "Outlines",
    "PerformanceChanges",
    "RandomUrns",
    "Summoners",
}

local current_overlay_widget = nil
local current_descriptions_widget = nil

local function create_descriptions_overlay_ui()
    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.7,
                bg_img = "black",
                id = "descriptions_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main descriptions container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {"100%", "100%"},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "descriptions_title",
                        type = "label",
                        text = "Mod Descriptions",
                        font_size = 36,
                        color = "cadetblue",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Description text
                    {
                        id = "descriptions_text",
                        type = "label",
                        text = [[SavageDuck26's Mod Descriptions:

- AddUtility: This is a required mod for many other mods to work, it has bug fixes and utility functions for other mods.
- Alliances: Mixes all enemy factions together.All players need the mod, or the game will crash for those without it.
- Berserkers: Enemies can enter Berserker and Juggernaut states with increased speed and health regen.
- CharacterSelect: Allows you to select different characters by opening the menu in game and pressing F3 or R2.
- ChaosMode: Allows all enemies and stones to spawn in hallways, and increased the amount of spawns by a large margin.
- Doppelgangers: Allows multiple of the same hero to be picked at once, played at once, and hotjoined with.
- DucksAddons: Just fun little changes that do not affect gameplay in any real way.
- DucksUI: You're looking at it. :D
- ColosseumStones: Adds Colosseum Stones into Endless. (New stones coming?)
- EndlessShop: Allows you to turn off certain shop items in Endless. Dead Broke doubles the cost of all shop items. (New items coming?)
- GraveTrappers: Enemies and stones drop traps or have effects when killed. (Spikes, Spinner Traps, Lava Columns, etc.)
- MeteorStorm: Lava levels have Meteors throughout them in Endless.
- MoreCrowns: Allows Crowns to spawn on all enemies. Has a UI that shows the amounts picked up by each player.
- NoCameraShake: Disables all camera shake effects.
- NoDarkFloors: Disables dark floors in Endless mode.
- NoGhosts: Replaces all ghost spawns with skeletons instead.
- Outlines: Outlines all characters on your screen for easier visibility.
- RandomUrns: Gold Urns, Goldrocks, Gold Crates, and other props if you choose, drop random items when destroyed.
- SkullcoinScarcity: Makes earning skullcoins 4x harder.
- Summoners: Caster enemies can summon additional enemies when they cast spells.
 
Trials Mods:
- DeadMansHand: Removes the ability to revive using Skullcoins.
- TheLaziestHero: Disables most inputs when not wearing the crown for the player with the mod.
 
Note: If any of these descriptions are still confusing, or you have any ideas for the mods, DM me on Discord: SavageDuck26. Other mods will be added here soon.
Coming Soon(ish): MarkedForDeath(FF). ]],
-- No longer than the Note line!!!
                        font_size = 32,
                        color = "cadetblue",
                        position = {"left + 5", "top - 450"},
                        text_align = "center",
                        size = {"100%", "98%"}
                    },
                    -- Back button
                    {
                        id = "descriptions_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 24,
                        color = "white",
                        position = {"center", "bottom - 30"},
                        size = {200, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                hide_descriptions_overlay()
                            end
                        }
                    }
                }
            }
        }
    }
end
local function create_documentation_overlay_ui()
    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.7,
                bg_img = "black",
                id = "documentation_overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main descriptions container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {"100%", "100%"},
                type = "container",
                children = {
                    -- Title
                    {
                        id = "documentation_title",
                        type = "label",
                        text = "Mod Documentation",
                        font_size = 36,
                        color = "cadetblue",
                        position = {"center", "top + 30"},
                        text_align = "center"
                    },
                    -- Description text
                    {
                        id = "documentation_text",
                        type = "label",
                        text = [[

Clientside Mods: (This means for the mod to work properly, all players need to have the mod installed)
- Alliances: This mod REQUIRES all players to have it, others will crash without it. It is still in development, so bugs may exist.
- ColosseumStones: This works serverside, however players without the mod will crash if Poison Towers are present.
- Doppelgangers: This mod does not require all players to have it, but will not function properly without it.
- EndlessShop: Dead Broke only functions for the player using the mod.
- MoreCrowns: The crown pickup UI will not appear for players without the mod.
 
Many thanks for reading this far. Any questions, concerns, etc. Lmk. ]],

                        font_size = 32,
                        color = "cadetblue",
                        position = {"left + 5", "top - 450"},
                        text_align = "center",
                        size = {"100%", "98%"}
                    },
                    -- Back button
                    {
                        id = "documentation_back_button",
                        type = "button",
                        text = "Back",
                        font_size = 24,
                        color = "white",
                        position = {"center", "bottom - 30"},
                        size = {200, 50},
                        style = "button_standard",
                        on = {
                            clicked = function()
                                hide_documentation_overlay()
                            end
                        }
                    }
                }
            }
        }
    }
end

function show_descriptions_overlay()
    if current_descriptions_widget then
        return
    end
    current_descriptions_widget = GUI:load_proto(create_descriptions_overlay_ui())
    GUI:add_modal_widget(current_descriptions_widget, GUI.MAIN_CONTROLLER)
end

function hide_descriptions_overlay()
    if not current_descriptions_widget then
        return
    end
    GUI:remove_modal_widget(current_descriptions_widget)
    GUI:destroy_widget(current_descriptions_widget)
    current_descriptions_widget = nil
end

local current_documentation_widget = nil

function show_documentation_overlay()
    if current_documentation_widget then
        return
    end
    current_documentation_widget = GUI:load_proto(create_documentation_overlay_ui())
    GUI:add_modal_widget(current_documentation_widget, GUI.MAIN_CONTROLLER)
end

function hide_documentation_overlay()
    if not current_documentation_widget then
        return
    end
    GUI:remove_modal_widget(current_documentation_widget)
    GUI:destroy_widget(current_documentation_widget)
    current_documentation_widget = nil
end

-- Check if a mod's show_config is available by safely checking the global
local function is_mod_config_available(global_name, func_name)
    local mod_table = rawget(_G, global_name)
    if not mod_table then return false end
    if func_name and type(mod_table) == "table" then
        return type(mod_table[func_name]) == "function"
    end
    -- For direct global functions (e.g. show_endlessshop_config)
    return type(mod_table) == "function"
end

local function create_duck_overlay_ui()
    local all_buttons_config = {
        {id = "berserkers_config", text = "Berserkers Config", callback = "Berserkers.show_config()", global = "Berserkers", func = "show_config"},
        {id = "chaosmode_config", text = "ChaosMode Config", callback = "ChaosMode.show_config()", global = "ChaosMode", func = "show_config"},
        {id = "colosseum_stones_config", text = "ColosseumStones Config", callback = "ColosseumStones.show_config()", global = "ColosseumStones", func = "show_config"},
        {id = "dialogue_freq_config", text = "DialogueFrequency Config", callback = "DialogueFrequency.show_config()", global = "DialogueFrequency", func = "show_config"},
        {id = "endless_shop_config", text = "EndlessShop Config", callback = "_G.show_endlessshop_config", global = "show_endlessshop_config", func = nil},
        {id = "gravetrappers_config", text = "GraveTrappers Config", callback = "GraveTrappers.show_config()", global = "GraveTrappers", func = "show_config"},
        {id = "knossos_config", text = "Knossos Config", callback = "Knossos.show_config()", global = "Knossos", func = "show_config"},
        {id = "meteor_storm_config", text = "MeteorStorm Config", callback = "MeteorStorm.show_config()", global = "MeteorStorm", func = "show_config"},
        {id = "more_crowns_config", text = "MoreCrowns Config", callback = "MoreCrowns.show_config()", global = "MoreCrowns", func = "show_config"},
        {id = "outlines_config", text = "Outlines Config", callback = "Outlines.show_config()", global = "Outlines", func = "show_config"},
        {id = "performance_config", text = "Performance Config", callback = "PerformanceChanges.show_config()", global = "PerformanceChanges", func = "show_config"},
        {id = "randomurns_config", text = "RandomUrns Config", callback = "RandomUrns.show_config()", global = "RandomUrns", func = "show_config"},
        {id = "summoners_config", text = "Summoners Config", callback = "Summoners.show_config()", global = "Summoners", func = "show_config"},
    }
    
    -- Filter to only include buttons whose mod is actually loaded
    local buttons_config = {}
    for _, btn in ipairs(all_buttons_config) do
        if is_mod_config_available(btn.global, btn.func) then
            table.insert(buttons_config, btn)
        end
    end
    
    local buttons_per_row = 4
    local button_width = 300
    local button_height = 60
    local horizontal_spacing = 20
    local vertical_spacing = 15
    local start_y = 120
    
    -- Calculate total width needed for centering
    local total_row_width = (button_width * buttons_per_row) + (horizontal_spacing * (buttons_per_row - 1))
    local start_x = -total_row_width / 2 + button_width / 2
    
    local button_children = {}
    
    for i, btn_config in ipairs(buttons_config) do
        local row = math.floor((i - 1) / buttons_per_row)
        local col = (i - 1) % buttons_per_row
        
        local x_pos = start_x + (col * (button_width + horizontal_spacing))
        local y_pos = start_y + (row * (button_height + vertical_spacing))
        
        table.insert(button_children, {
            id = btn_config.id,
            type = "button",
            text = btn_config.text,
            font_size = 22,
            color = "white",
            position = {"center + " .. x_pos, "top + " .. y_pos},
            size = {button_width, button_height},
            style = "button_standard",
            on = {
                clicked = function()
                    local func_name = btn_config.callback
                    if func_name then
                        local ok, func = pcall(loadstring, "return " .. func_name)
                        if ok and func then
                            local ok2, result = pcall(func)
                            if ok2 and type(result) == "function" then
                                pcall(result)
                            end
                        end
                    end
                end
            }
        })
    end
    
    -- Build the complete children array
    local main_children = {
        -- Title
        {
            id = "overlay_title",
            type = "label",
            text = "Duck's Mods Menu",
            font_size = 36,
            color = "cadetblue",
            position = {"center", "top + 30"},
            text_align = "center"
        }
    }
    
    -- Add all button children
    for _, btn in ipairs(button_children) do
        table.insert(main_children, btn)
    end
    
    -- Add back button
    table.insert(main_children, {
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
                hide_duck_overlay()
            end
        }
    })
    table.insert(main_children, {
        id = "mod_descriptions",
        type = "button",
        text = "Descriptions",
        font_size = 26,
        color = "cadetblue",
        position = {"top + 20", "left + 20"},
        size = {225, 60},
        style = "button_standard",
        on = {
            clicked = function()
                show_descriptions_overlay()
            end
        }
    })
    table.insert(main_children, {
        id = "mod_documentation",
        type = "button",
        text = "Documentation",
        font_size = 26,
        color = "cadetblue",
        position = {"top + 240", "left + 20"},
        size = {225, 60},
        style = "button_standard",
        on = {
            clicked = function()
                show_documentation_overlay()
            end
        }
    })
    -- Description
    table.insert(main_children, {
        id = "description",
        type = "label",
        text = "SavageDuck26's Mod Configs. Settings Auto-save on menu exit. Other Configs in progress...",
        font_size = 24,
        color = "cadetblue",
        position = {"center", "top + 80"},
        text_align = "center",
    })
    table.insert(main_children, {
        id = "description_funny",
        type = "label",
        text = "No ducks were harmed in the making of this menu. If you have requests, ideas, or concerns, shoot me a message.",
        font_size = 24,
        color = "cadetblue",
        position = {"center", "bottom - 90"},
        text_align = "center",
    })
    
    return {
        css = "gui/default_css",
        type = "container",
        size = {"100%", "100%"},
        children = {
            -- Semi-transparent background
            {
                alpha = 0.7,
                bg_img = "black",
                id = "overlay_background",
                position = {"center", "top"},
                size = {"100%", "100%"}
            },
            -- Main overlay container
            {
                bg_img = "menu_standard_background_stone",
                position = {"center", "center"},
                size = {1400, 700},
                type = "container",
                children = main_children
            }
        }
    }
end

-- Function to show the overlay
function show_duck_overlay()
    if current_overlay_widget then
        return -- Already showing
    end
    if DucksUI.import_all_settings then
        pcall(DucksUI.import_all_settings)
    end
    current_overlay_widget = GUI:load_proto(create_duck_overlay_ui())
    
    GUI:add_modal_widget(current_overlay_widget, GUI.MAIN_CONTROLLER)    
end

function hide_duck_overlay()
    if not current_overlay_widget then
        return
    end

    if DucksUI.save_all_settings then
        pcall(DucksUI.save_all_settings)
    end

    GUI:remove_modal_widget(current_overlay_widget)
    
    GUI:destroy_widget(current_overlay_widget)
    current_overlay_widget = nil
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "foundation/lua/util/json" then
        if DucksUI.import_all_settings then
            pcall(DucksUI.import_all_settings)
        end
    end

    if path == "lua/menu/screen_main_menu" then

        if DucksUI.import_all_settings then
            pcall(DucksUI.import_all_settings)
        end

        Mods.hook:set(MOD_NAME, "ScreenMainMenu.rebuild_ui", function (orig, self)            
            orig(self)
            
            local duck_button = {
                id = "ducks_mods_menu",
                style = "title_large",
                type = "button",
                text = "Ducks Mods",
                color = "cadetblue",
                font_size = 64,
                on = {
                    selected = function ()
                        self:show_tooltip("Ducks Mod Menu UI")
                    end,
                    clicked = function ()
                        show_duck_overlay()
                    end,
                },
            }
            
            local custom_duck_widget = GUI:load_proto(duck_button)
            self.widget:get("buttons"):add_child(custom_duck_widget)
        end)
    end

    -- add a lobby button when the lobby screen is required
    if path == "lua/menu/screen_lobby" then
        Mods.hook:set(MOD_NAME, "ScreenLobby.rebuild_ui", function(orig, self, user_name)
            orig(self, user_name)

            local widget = self.widget
            if widget then
                local duck_button = {
                    id = "ducks_mods_menu_lobby",
                    style = "button_standard",
                    type = "button",
                    text = "Ducks Mods",
                    color = "cadetblue",
                    font_size = 36,
                    position = {"left + 20", "bottom - 20"},
                    on = {
                        selected = function()
                            -- Nothing, no tooltips here.
                        end,
                        clicked = function()
                            show_duck_overlay()
                        end,
                    },
                }

                local custom_duck_widget = GUI:load_proto(duck_button)
                local host_btn = widget:get("host_options_button")

                if host_btn then
                    local parent = host_btn:get_parent()
                    if parent then
                        parent:add_child(custom_duck_widget)
                    else
                        widget:add_child(custom_duck_widget)
                    end
                else
                    widget:add_child(custom_duck_widget)
                end
            end
        end)
    end


    return result
end)

local function encode_json(obj)
    local function encode_value(val)
        local val_type = type(val)
        if val_type == "string" then
            return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
        elseif val_type == "number" then
            return tostring(val)
        elseif val_type == "boolean" then
            return tostring(val)
        elseif val_type == "table" then
            local result = {}
            local is_array = true
            for k, v in pairs(val) do
                if type(k) ~= "number" then
                    is_array = false
                    break
                end
            end
            
            if is_array then
                for i, v in ipairs(val) do
                    table.insert(result, encode_value(v))
                end
                return "[" .. table.concat(result, ",") .. "]"
            else
                for k, v in pairs(val) do
                    table.insert(result, '"' .. tostring(k) .. '":' .. encode_value(v))
                end
                return "{" .. table.concat(result, ",") .. "}"
            end
        else
            return "null"
        end
    end
    return encode_value(obj)
end

local function decode_json(str)
    local function decode_value(s, pos)
        local first = s:sub(pos, pos)
        if first == '"' then
            local end_pos = pos + 1
            while end_pos <= #s do
                local char = s:sub(end_pos, end_pos)
                if char == '"' and s:sub(end_pos - 1, end_pos - 1) ~= '\\' then
                    break
                end
                end_pos = end_pos + 1
            end
            return s:sub(pos + 1, end_pos - 1):gsub('\\"', '"'):gsub('\\\\', '\\'), end_pos + 1
        elseif first == '{' then
            local obj = {}
            pos = pos + 1
            while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
            if s:sub(pos, pos) == '}' then return obj, pos + 1 end
            
            while true do
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                local key, new_pos = decode_value(s, pos)
                pos = new_pos
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                if s:sub(pos, pos) == ':' then pos = pos + 1 end
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                local value
                value, pos = decode_value(s, pos)
                obj[key] = value
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                if s:sub(pos, pos) == '}' then return obj, pos + 1 end
                if s:sub(pos, pos) == ',' then pos = pos + 1 end
            end
        elseif first == '[' then
            local arr = {}
            pos = pos + 1
            while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
            if s:sub(pos, pos) == ']' then return arr, pos + 1 end
            
            while true do
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                local value
                value, pos = decode_value(s, pos)
                table.insert(arr, value)
                while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
                if s:sub(pos, pos) == ']' then return arr, pos + 1 end
                if s:sub(pos, pos) == ',' then pos = pos + 1 end
            end
        elseif s:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        elseif s:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        elseif s:sub(pos, pos + 3) == "null" then
            return nil, pos + 4
        else
            local num_end = pos
            while num_end <= #s and s:sub(num_end, num_end):match("[%d%.%-]") do
                num_end = num_end + 1
            end
            return tonumber(s:sub(pos, num_end - 1)), num_end
        end
    end
    
    if str and str ~= "" then
        local result, _ = decode_value(str, 1)
        return result
    end
    return {}
end

-- prettify a compact JSON string by adding indentation and newlines
local function pretty_json(str)
    local indent = 0
    local in_string = false
    local result = ""
    for i = 1, #str do
        local c = str:sub(i, i)
        if c == '"' and str:sub(i - 1, i - 1) ~= '\\' then
            in_string = not in_string
            result = result .. c
        elseif not in_string then
            if c == '{' or c == '[' then
                indent = indent + 1
                result = result .. c .. "\n" .. string.rep("  ", indent)
            elseif c == '}' or c == ']' then
                indent = indent - 1
                result = result .. "\n" .. string.rep("  ", indent) .. c
            elseif c == ',' then
                result = result .. c .. "\n" .. string.rep("  ", indent)
            elseif c == ':' then
                result = result .. c .. " "
            else
                result = result .. c
            end
        else
            result = result .. c
        end
    end
    return result
end

-- Get a writable settings file path
-- Tries multiple locations in order of preference
local _cached_settings_path = nil
local function get_settings_file_path()
    if _cached_settings_path then
        return _cached_settings_path
    end
    
    local filename = "ducks_ui_mod_settings.json"
    local paths_to_try = {}
    
    -- Game sandbox only allows writes under custom/logs/ or custom/settings/
    -- Try these first since they are the most likely to work
    table.insert(paths_to_try, "custom/settings/" .. filename)
    
    -- Try to get AppData path as a fallback (works outside sandbox)
    local appdata = os.getenv("APPDATA")
    if appdata then
        local gauntlet_folder = appdata .. "\\Arrowhead\\Gauntlet"
        table.insert(paths_to_try, gauntlet_folder .. "\\" .. filename)
    end
    
    -- Try user's home directory
    local userprofile = os.getenv("USERPROFILE")
    if userprofile then
        table.insert(paths_to_try, userprofile .. "\\Documents\\" .. filename)
    end
    
    -- Finally try current directory (original behavior, least likely to work)
    table.insert(paths_to_try, filename)
    
    local function is_writable(path)
        local file, err = io.open(path, "a")
        if file then
            file:close()
            return true
        end
        -- Save error from inaccessible location for debugging
        print("[DucksUI] Could not open path for write: " .. path .. " (" .. tostring(err) .. ")")
        return false
    end

    -- Test which path is writable
    for _, path in ipairs(paths_to_try) do
        if is_writable(path) then
            _cached_settings_path = path
            print("[DucksUI] Using settings path: " .. path)
            return path
        end
    end

    -- Return first choice even if we couldn't test it
    _cached_settings_path = paths_to_try[1] or filename
    print("[DucksUI] Warning: Could not verify writable path, using: " .. _cached_settings_path)
    return _cached_settings_path
end

-- Helper function to round floats to hundredths place
local function round_floats(obj)
    if type(obj) == "number" then
        -- Round to thousandths place (0.001)
        return math.floor(obj * 1000 + 0.5) / 1000
    elseif type(obj) == "table" then
        local rounded = {}
        for k, v in pairs(obj) do
            rounded[k] = round_floats(v)
        end
        return rounded
    else
        return obj
    end
end

-- Deep merge saved settings into existing defaults
-- Saved values override defaults, but missing keys keep their default values
local function deep_merge(defaults, saved)
    if type(defaults) ~= "table" or type(saved) ~= "table" then
        return saved
    end
    local merged = {}
    for k, v in pairs(defaults) do
        if saved[k] ~= nil then
            merged[k] = deep_merge(v, saved[k])
        else
            merged[k] = v
        end
    end
    -- Also bring in any saved keys not in defaults (new settings added by user)
    for k, v in pairs(saved) do
        if merged[k] == nil then
            merged[k] = v
        end
    end
    return merged
end

local function save_all_ui_player_settings()
    local settings = {}

    -- EndlessShop still uses old pattern
    if rawget(_G, "update_endlessshop_config") then
        pcall(rawget(_G, "update_endlessshop_config"))
    end
    
    -- Collect CONFIG from every registered mod that exists
    for _, name in ipairs(REGISTERED_MODS) do
        local mod = rawget(_G, name)
        if mod then
            if mod.CONFIG then
                settings[name] = round_floats(mod.CONFIG)
                print("[DucksUI] Collected settings for mod: " .. name)
            else
                print("[DucksUI] Mod has no CONFIG table (skipping): " .. name)
            end
        else
            print("[DucksUI] Mod not loaded in global namespace (skipping): " .. name)
        end
    end

    -- EndlessShop still uses old pattern
    local endlessshop_config = rawget(_G, "endlessshop_config")
    if endlessshop_config then
        settings.endlessshop_config = endlessshop_config
    end
    
    -- Round ALL settings to thousandths place before encoding
    settings = round_floats(settings)
    
    -- Use the path helper to find a writable location
    local json_file_path = get_settings_file_path()
    
    local json_content
    local encode_ok, encode_result = pcall(function()
        if JSON and JSON.encode_value then
            return JSON.encode_value(settings)
        else
            return encode_json(settings)
        end
    end)
    
    if not encode_ok then
        print("[DucksUI] Error encoding settings: " .. tostring(encode_result))
        return nil
    end
    json_content = encode_result
    
    -- pretty-print if helper exists
    if pretty_json and json_content then
        local ok, pretty_result = pcall(pretty_json, json_content)
        if ok then
            json_content = pretty_result
        end
    end
    
    local file, err = io.open(json_file_path, "w")
    if file then
        local write_ok, write_err = pcall(function()
            file:write(json_content)
            file:close()
        end)
        
        if write_ok then
            print("[DucksUI] Settings saved successfully to: " .. json_file_path)
        else
            print("[DucksUI] Error writing settings: " .. tostring(write_err))
            pcall(function() file:close() end)
            return nil
        end
    else
        print("[DucksUI] Could not open settings file for writing: " .. json_file_path)
        print("[DucksUI] Error: " .. tostring(err))
        return nil
    end
    return settings
end

local function import_all_ui_player_settings()
    -- Use the path helper to find the settings file
    local json_file_path = get_settings_file_path()
        
    local file, err = io.open(json_file_path, "r")
    if not file then
        -- This is normal on first run - no settings file exists yet
        print("[DucksUI] No settings file found (first run or new install)")
        return
    end
    
    local read_ok, json_content = pcall(function()
        local content = file:read("*all")
        file:close()
        return content
    end)
    
    if not read_ok then
        print("[DucksUI] Error reading settings file: " .. tostring(json_content))
        pcall(function() file:close() end)
        return
    end
                
    if not json_content or json_content == "" then
        print("[DucksUI] Settings file is empty")
        return
    end
    
    local decode_ok, settings = pcall(function()
        if JSON and JSON.decode_value then
            return JSON.decode_value(json_content)
        else
            return decode_json(json_content)
        end
    end)
    
    if not decode_ok then
        print("[DucksUI] Error decoding settings: " .. tostring(settings))
        return
    end
    
    if not settings or type(settings) ~= "table" then
        print("[DucksUI] Invalid settings format")
        return
    end
    
    print("[DucksUI] Loading settings from: " .. json_file_path)
    
    -- Apply CONFIG from settings to every registered mod that exists
    -- Uses deep_merge so that missing nested tables keep their defaults
    for _, name in ipairs(REGISTERED_MODS) do
        local saved = settings[name]
        if saved then
            local mod = rawget(_G, name)
            if mod then
                if mod.CONFIG and type(mod.CONFIG) == "table" then
                    mod.CONFIG = deep_merge(mod.CONFIG, saved)
                else
                    mod.CONFIG = saved
                end
                if mod.load_config then pcall(mod.load_config) end
            end
        end
    end
    
    -- EndlessShop still uses old pattern
    if settings.endlessshop_config then
        rawset(_G, "endlessshop_config", settings.endlessshop_config)
        if rawget(_G, "update_endlessshop_from_config") then
            pcall(rawget(_G, "update_endlessshop_from_config"))
        end
    end
    
    print("[DucksUI] Settings loaded successfully")
end

-- Migration helper: Try to find settings from the old location and migrate them
local function migrate_old_settings()
    local new_path = get_settings_file_path()
    
    -- Check all old locations where settings might have been saved
    local old_paths = { "ducks_ui_mod_settings.json" }
    local appdata = os.getenv("APPDATA")
    if appdata then
        table.insert(old_paths, appdata .. "\\Gauntlet\\ducks_ui_mod_settings.json")
        table.insert(old_paths, appdata .. "\\Arrowhead\\Gauntlet\\ducks_ui_mod_settings.json")
    end
    
    -- If new settings already exist, no migration needed
    local new_file = io.open(new_path, "r")
    if new_file then
        new_file:close()
        return
    end
    
    -- Try each old location
    for _, old_path in ipairs(old_paths) do
        if old_path ~= new_path then
            local old_file = io.open(old_path, "r")
            if old_file then
                local content = old_file:read("*all")
                old_file:close()
                
                if content and content ~= "" then
                    local new_write = io.open(new_path, "w")
                    if new_write then
                        new_write:write(content)
                        new_write:close()
                        print("[DucksUI] Migrated settings from " .. old_path .. " to: " .. new_path)
                        return
                    end
                end
            end
        end
    end
end

-- Run migration on load
pcall(migrate_old_settings)

-- Export functions on DucksUI namespace
DucksUI.save_all_settings = save_all_ui_player_settings
DucksUI.import_all_settings = import_all_ui_player_settings
DucksUI.get_settings_path = get_settings_file_path

-- Also keep legacy global exports for backwards compatibility
rawset(_G, "save_all_ui_player_settings", save_all_ui_player_settings)
rawset(_G, "import_all_ui_player_settings", import_all_ui_player_settings)
