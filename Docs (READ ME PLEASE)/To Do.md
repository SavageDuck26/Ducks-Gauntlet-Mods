## Known Bugs (no order):
*Bug:* RandomLoadout needs a visual update fix, loadouts don't update for those without the mods. (Reported by Siopilos)
*Proposed Fix:* Add update func for non-modded in AddUtil

*Bug:* New lava floor enemies sometimes prevent room doors from opening. If all players rejoin, the host can use the hidden ball to open the room.
*Proposed Fix:* AddUtil update func to watch `cultist_armor_corpse` and force cleanup after ~15 seconds?

*Bug:* Orb effects (Elementals) do not work when you are inside Wiza Barrier / Valkyrie Shield Pot, or when you break orbs using immune abilities (Thor Murder, Valkyrie AoE weapon, or dash on orbs). (Reported by Siopilos) 
*Proposed Fix:* Change effects to ignore i-frames by applying instead of effecting.

*Bug:* Pots cooldown + RandomLoadout do not display cooldown visuals correctly. (Reported by Siopilos)
*Proposed Fix:* N/A

*Bug:* Enemy ignore bug: Sometimes enemies ignore certain players. Happens when using Doppelgangers, if a player is the “second doppelganger” they become invisible to the host.
*Proposed Fix:* Overhaul entire system, too many bugs present. Assign unique IDs?

*Bug:* New Chaos Mode causes issues for players with low-performance PCs.
*Proposed Fix:* Find a way to lower CPU usage. 

*Bug:* RandomHero duplicates all potions and keys for non-host players when changing floors.
*Proposed Fix:* Force it to only run locally?

*Bug:* RandomHero sometimes does not drop other players on floor change. Doppelgangers fixes this.
*Proposed Fix:* N/A

*Bug:* TheLaziestHero and Curse Trial can crash for non-host players.
*Proposed Fix:* N/A

*Bug:* Knossos with extra rooms can lock players behind key doors if it's the first room encountered. 
*Proposed Fix:* Higher chances for key drops based on amount of keydoors spawned?

*Bug:* Fire Bomber explosion visuals do not appear.
*Proposed Fix:* N/A

## Mod Suggestions (by priority):
- It would be a nice optimization for melee heroes if Lich balls only appeared when the ghost summon cast is completed.
- Culling system fix for Knossos and Alliances, too many bosses/lag. (Partly implemented, needs testing and maybe updates.)
- Increase Eye Boss threat range.
- When a player dies, revive them as Lazy for the next floor only, or revive them as Lazy forever.
- When a player loots any gold on this floor he instand became lazy for this floor.
- Players able to swap in game between all 3 potion abilities.
- Fifth Player.
- Add more death bosses.

## Outside Modding: 
- Custom levels: Caves level that spirals downwards to unlock a massive elevator in the middle that brings to surface where a boss is?