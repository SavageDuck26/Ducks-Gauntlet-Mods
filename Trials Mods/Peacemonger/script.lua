-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.0
-- Purpose: If more than 1 kill, Trial is failed.
-- =================================================================================================

local MOD_NAME = "Peacemonger"

Peacemonger = Peacemonger or {}

Peacemonger.check_kills = function(kills)
    if kills > 1 then
        AddUtility.show_text("top", "Peacemonger Trial Failed: " .. kills .. " kills.", 5, "purple", 48, "PeacemongerTrial")
        AddUtility.send_text_chat(MOD_NAME,"Peacemonger Trial Failed: " .. kills .. " kills.")
        
    end
end

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/components/stats_component" then 
        print("[" .. MOD_NAME .. "]" .. path .. " loaded")

        Mods.hook:set(MOD_NAME, "StatsComponent.command_master", function(orig, self, unit, context, command_name, data)
            local state = context.state -- Need this to access data

            orig(self, unit, context, command_name, data)
            
            if command_name == "avatar_killed_something" then
                local victim_type = data.victim_type
                if victim_type == "monster" then
                    local kills = state.enemy_kills or 0
                    Peacemonger.check_kills(kills)
                end
            end
        end)
    end

    return result
end)