
local MOD_AUTHOR = "SavageDuck26"
local MOD_DESCRIPTION = "Fixes issues with Cultist Armor behavior"


local MOD_NAME, log_message = Mods.init_mod()

local CORPSE_PATH = "characters/cultist_armor/cultist_armor_corpse"

-- `reform` re-spawns the armour at frame 220 of its 300 (~3.7s on the engine's 60Hz tick), so a
-- corpse still standing once that ability ends has had its re-spawn and is spent.
local CORPSE_RETIRE_DELAY = 5.0

local function is_corpse(unit)
    local path = Unit.get_data(unit, "unit_path") or Unit.get_data(unit, "settings_path")

    return path == CORPSE_PATH
end

-- The corpse carries `enemy`, so the encounter counts it among the enemies holding the doors shut and
-- nothing but its death removes it. Keep it out of the encounter's books; it stays destructible.
Mods.hook:set_object_path("DungeonManager", "add_unit", function (orig, self, unit)
    if is_corpse(unit) then
        return
    end

    return orig(self, unit)
end, MOD_NAME .. ".DungeonManager.add_unit", MOD_NAME)

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

        -- Retire spent corpses so nothing orphaned is left standing for the rest of the floor. The
        -- reform itself is left alone, so the armour still gets its chance to come back.
        result.time_before_decay = 0

        local original_register = result.on_entity_registered

        result.on_entity_registered = function (unit)
            if original_register then
                pcall(original_register, unit)
            end

            if not EntityAux.owned(unit) then
                return
            end

            -- A client interacting with the corpse migrates it to itself (the corpse is
            -- `require_migration`, interactable_component.lua:352) and migrating away drops this peer's
            -- master contexts (entity_manager.lua:254) while the unit stays alive as a prediction, so
            -- "alive" is not enough: `call_master` indexes the master context and throws without it.
            AddUtility.delay_action(CORPSE_RETIRE_DELAY, function ()
                if Unit.alive(unit) and EntityAux.has_component_master(unit, "enemy") then
                    EntityAux.call_master(unit, "enemy", "decay")
                end
            end)
        end

        -- The interact is owner-gated, so a client's attempt leaves the corpse on the host. "decay" is
        -- the safe teardown here -- force_despawn/despawn_entity/destroy_unit crash mid-interact.
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