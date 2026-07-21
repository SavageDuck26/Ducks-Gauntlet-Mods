-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.1
-- Purpose: Make skullcoin gain 4x harder to earn.
-- =================================================================================================

local MOD_NAME = "SkullcoinScarcity"
print("[" .. MOD_NAME .. "] Skullcoin stock goes down down down!")

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    if path == "lua/managers/party_lead_manager" and PartyLeadManager then
        -- Only override the static calculation function
        PartyLeadManager.kill_score_for_coin = function(_, num_skull_coins)
            -- 4x harder: base is 400, scaling factor is 2 (default)
            local base = 400
            local scale = 2
            return base * (1 + scale * num_skull_coins)
        end
    end
    return result
end)