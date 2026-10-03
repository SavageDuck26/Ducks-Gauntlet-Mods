
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Fixes issues with Cultist Armor behavior"


local MOD_NAME, log_message = Mods.init_mod()

Mods.hook:set_object(_G, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "characters/cultist_armor/cultist_armor" and result then
        if result.abilities and result.abilities.stab and result.abilities.stab.events then
            for _, event in ipairs(result.abilities.stab.events) do
                if event.half_extents then
                    event.half_extents.y = 1.5  -- Reduced from 2.5 to prevent piercing shields
                end
            end
        end
    end

    if path == "characters/cultist_armor/cultist_armor_corpse" and result then
        result.interact_text = "Destroy Reforming Armor"

        -- The corpse is immune to every damage type, so the destruction interact below is the only
        -- thing that kills it. That interact fires a flow event and queues a "damage" command on the
        -- damage_receiver -- but the component defines no command_master, so the queued command is a
        -- no-op (BaseComponent.command_master just returns). The corpse's death therefore rides
        -- entirely on its own flow and never reaches the peers that don't own it: the owner records
        -- the kill, so its room opens, while every other peer keeps the corpse and its room keeps
        -- waiting on it (the "leave and rejoin, then the host can open the room" bug). Own the
        -- teardown here instead: on the owner, push the corpse through the game's own despawner,
        -- which destroys the networked game object so every peer drops it.
        local original_interact_result = result.interactable_interact_result

        result.interactable_interact_result = function (component, interactable, interactor, success)
            if original_interact_result then
                original_interact_result(component, interactable, interactor, success)
            end

            if success and interactable and Unit.alive(interactable) and EntityAux.owned(interactable) then
                local despawner = FlowCallbacks.state_game and FlowCallbacks.state_game.despawner

                if despawner then
                    despawner:force_despawn(interactable)
                end
            end
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)