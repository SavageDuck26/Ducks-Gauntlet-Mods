
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
        -- entirely on its own flow and does not reliably reach the peers that don't own it, leaving the
        -- room held open on them (the "leave and rejoin, then the host can open the room" bug).
        --
        -- Do NOT try to tear the corpse down from this callback (despawner:force_despawn,
        -- EntitySpawner:despawn_entity or AddUtility.destroy_unit all crash): none of them are safe
        -- while the interact is in flight. InteractableComponent.on_interact_result keeps using
        -- interactable_unit after this returns (set_accepted_interactor / set_enabled), and
        -- World.destroy_unit frees it there and then. Hand the corpse to the engine's own death ->
        -- decay path instead: "decay" is exactly what StateCommon.decay_enter uses for every dead
        -- enemy. It only queues work -- it broadcasts rpc_start_decay so every peer decays the corpse
        -- too, and the final teardown is timer-based, so it runs long after the interact has finished.
        local original_interact_result = result.interactable_interact_result

        result.interactable_interact_result = function (component, interactable, interactor, success)
            if original_interact_result then
                original_interact_result(component, interactable, interactor, success)
            end

            if success and interactable and Unit.alive(interactable) and EntityAux.owned(interactable) then
                EntityAux.call_master(interactable, "enemy", "decay")
            end
        end
    end

    return result
end, MOD_NAME .. ".require", MOD_NAME)