-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.2
-- Purpose: Removes camera shaking effects.
-- =================================================================================================

NoCameraShake = NoCameraShake or {}
NoCameraShake.loaded = true

local MOD_NAME = "NoCameraShake"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)
    
    if path == "foundation/lua/util/camera_shaker" and CameraShaker and CameraShaker.create_shake then
        local original_create_shake = CameraShaker.create_shake
        CameraShaker.create_shake = function(self, info, epicenter)
            return {
                envelope = {attack_time=0, hold_time=0, decay_time=0, sustain_time=0, release_time=0},
                max_amplitude = {x=0, y=0},
                amplitude = {x=0, y=0},
                sustain_amplitude = {x=0, y=0},
                frequency = {x=0, y=0},
                use_noise = false,
                mode = "release",
                timer = 0,
                total_duration = 0,
                dirty = true
            }
        end
    end
    return result
end)