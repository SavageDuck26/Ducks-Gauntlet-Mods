-- =================================================================================================
-- Author: SavageDuck26
-- Version: 1.0
-- Purpose: Adds new tips from an old someone.
-- =================================================================================================

local MOD_NAME = "LoadScreenDaemon"

Mods.hook:set(MOD_NAME, "require", function(orig, path, ...)
    local result = orig(path, ...)

    if path == "lua/states/load_screen_daemon" then
        
        Mods.hook:set(MOD_NAME, "LoadScreenDaemon.start", 
            function (orig, self, floor_id)

                if self.visible then
                    return
                end

                FadeManager:fade_in()
                GUI:set_enable_particles(false)
                GUI:destroy_all_particles()

                self.visible = true
                self.fade_in_time = self.time

                if self.widget == nil then
                    self.widget = GUI:load_widget_at("gui/load_screen_ui")
                end

                local layout_info = _G.DUNGEON_LAYOUTS[floor_id]
                local environment

                if table.array_find(GAME_ENVIRONMENTS, layout_info.environment) then
                    environment = layout_info.environment
                else
                    local difficulty = DifficultyManager:difficulty_setting()

                    environment = ProfileManager:get_active_environment(difficulty)
                end

                local img = EnvironmentSettings[environment].load_screen

                self.widget:get("loading_screen_image"):set_bg_img(img)
                GUI:add_widget(self.widget)

                local tip_strings = {
                    "Top: Wait what, that's not a tip! Someone get Morak over here!",
                    "Tip: Don't drink and drive.",
                    "???: Blue Jester needs food badly! Wait, wrong game.",
                    "???: Does anyone even read these?",
                    "???: Morak's been slacking lately if you ask me.",
                    "???: These heros never tip when buying my items...",
                    "???: Gonna have to sweep the halls again I guess...",
                    "???: What is this game? Some sort of Dark Legacy? Heh...",
                    "???: What are we? Some kind of Legends? Heh...",
                    "???: At least keep it down on this run, you've been giving me migraines.",
                    "???: I swear, if one more person asks me about the secret level...",
                    "Tip: Food is good",
                    "???: I heard the Elf lost his bow last run.",
                    "???: I heard the Valkyrie lost her shield last run.",
                    "???: I heard the Wizard lost his tome last run.",
                    "???: I heard the Warrior lost his axe last run.",
                    "???: I heard the Necromancer lost her staff last run.",
                    "???: Guess I'll sell their lost items back to them.",
                    "???: Who am I? I got removed in the big update.",
                    "???: Stop stealing all of the gold, Morak won't pay me if he has none.",
                    "???: I need a potion.",
                    "???: I don't haggle, the price is the price.",
                    "???: I'm aware some of my wares suck, I'm working on it.",
                    "???: Never was a fan of that gargoyle.",
                    "???: Whataya buyin'? Heh heh, just something an old friend used to say.",
                    "Merchant: Hey! They aren't supposed to know that!",
                    "???: Some of you heros need to learn some manners. I saw Thor practically inhale a turkey.",
                    "???: Am I from the Crypt? No, I just moved in.",
                    "???: I hear the Caves are nice this time of year.",
                    "???: Yeesh, it's hot down in Hell, and the chanting was a bit much.",
                    "???: I wonder if we'll ever get another game...",
                    "???: Stop leaving your empty potion bottles around!",
                    "???: Resetting the layout every run is getting exhausting.",
                    "???: Where the hell did these new monsters come from? Is Morak experimenting again?",
                    "???: I miss my old hub.",
                    "???: Everytime I sweep the heros come back and mess it all up again...",
                    "???: Do you know how many urns and vases I've had to replace?",
                    "???: The Sword of Tyrfing? I hardly know her!",
                }
                
                local tip_text = self.widget:get("tip_text")
                local tip_text_shadow = self.widget:get("tip_text_shadow")
                local tip_string = tip_strings[math.random(#tip_strings)]

                tip_text:set_text(tip_string)
                tip_text_shadow:set_text(tip_string)
                self.widget:set_alpha(1)
                self.widget:get("contents"):set_alpha(0)
                GUI:finalize_layout()

            end)
    end
    return result
end)