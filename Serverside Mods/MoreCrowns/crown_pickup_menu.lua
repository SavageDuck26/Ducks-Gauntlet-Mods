-- =================================================================================================
-- Author: SavageDuck26
-- Purpose: UI to display crown pickup counts at the start of each floor
-- =================================================================================================

local MOD_NAME = "CrownPickupMenu"

MoreCrowns = MoreCrowns or {}
MoreCrowns.CONFIG.crown_pickup_ui = MoreCrowns.CONFIG.crown_pickup_ui == nil and true or MoreCrowns.CONFIG.crown_pickup_ui
MoreCrowns.crowns_held_currently = MoreCrowns.crowns_held_currently or {}
MoreCrowns.crowns_picked_up_total = MoreCrowns.crowns_picked_up_total or {}
MoreCrowns.crowns_picked_up_floor = MoreCrowns.crowns_picked_up_floor or {}

local is_showing_ui = false

local function show_crowns_pickup_ui(endless_client)
    if is_showing_ui then
        return
    end
    is_showing_ui = true

    Game:delay_action(5, function()
        local players = {}
        for go_id, player_info in PlayerManager:players_iterator() do
            if player_info then
                local name = player_info.name or player_info.display_name or player_info.player_name or "Unknown"
                local floor_count = MoreCrowns.crowns_picked_up_floor[name] or 0
                local total_count = MoreCrowns.crowns_picked_up_total[name] or 0
                table.insert(players, {name = name, floor = floor_count, total = total_count})
            end
        end

        table.sort(players, function(a, b) return a.floor > b.floor end) -- Sort by Floor Count

        local widget = GUI:load_proto(_G.CrownPickupUI)

        GUI:add_modal_widget(widget, GUI.MAIN_CONTROLLER)
        widget:get("crown_popup"):set_visible(true)

        for i = 1, 4 do
            local player_text = widget:get("crown_player_" .. i)
            if players[i] then
                local name = players[i].name
                local floor_count = players[i].floor
                local total_count = players[i].total
                player_text:set_text(name .. "- Crowns Last Floor: " .. floor_count .. " [Total Crowns: " .. total_count .. "]")
                player_text:set_visible(true)
            else
                player_text:set_visible(false)
            end
        end

        Game:delay_action(5, function()
            if widget then
                GUI:remove_modal_widget(widget)
                GUI:destroy_widget(widget)
            end
            is_showing_ui = false
            MoreCrowns.crowns_picked_up_floor = {}
        end)
    end)
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "gui/crown_pickup_ui" then
        return _G.CrownPickupUI
    end

    if path == "lua/managers/endless_client" then
        Mods.hook:set(MOD_NAME, "EndlessClient.show_floor_start_popup", function(orig, self)
            orig(self)

            local floor_index = self._floor_index or 1
            if floor_index == 1 then
                is_showing_ui = false
                MoreCrowns.crowns_held_currently = {}
                MoreCrowns.crowns_picked_up_total = {}
                MoreCrowns.crowns_picked_up_floor = {}
            end

            if MoreCrowns.CONFIG.crown_pickup_ui and floor_index ~= 1 then
                show_crowns_pickup_ui(self)

            end
        end)
    end
    
    return result
end)

