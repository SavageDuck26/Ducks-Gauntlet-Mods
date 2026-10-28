## Known Bugs (no order):
*Bug:* RandomLoadout needs a visual update fix, loadouts don't update for those without the mods. (Reported by Siopilos) \
*Proposed Fix:* Add update func for non-modded in AddUtil.

*Bug:* New lava floor enemies sometimes prevent room doors from opening. If all players rejoin, the host can use the hidden ball to open the room. \
*Proposed Fix:* AddUtil update func to watch `cultist_armor_corpse` and force cleanup after ~15 seconds?

*Bug:* Orb effects (Elementals) do not work when you are inside Wiza Barrier / Valkyrie Shield Pot, or when you break orbs using immune abilities (Thor Murder, Valkyrie AoE weapon, or dash on orbs). (Reported by Siopilos) \
*Proposed Fix:* Change effects to ignore i-frames by applying instead of effecting.

*Bug:* Pots cooldown + RandomLoadout do not display cooldown visuals correctly. (Reported by Siopilos) \
*Proposed Fix:* N/A

*Bug:* Random Items visuals display correctly for all heroes on the 1st floor, but after using a teleport or entering the next room, the visuals become incorrect again. \
*Proposed Fix:* N/A

*Bug:* A double crown bug happens only when the player has the crown and drops it by knocking back. \
*Proposed Fix:* N/A

*Bug:* Enemy ignore bug: Sometimes enemies ignore certain players. Happens when using Doppelgangers, if a player is the “second doppelganger” they become invisible to the host. \
*Proposed Fix:* Overhaul entire system, too many bugs present. Assign unique IDs?

*Bug:* Fire Bomber explosion visuals do not appear. \
*Proposed Fix:* N/A

*Bug:* Knossos with extra rooms can lock players behind key doors if it's the first room encountered. Extra keys from RandomUrns fixes this. \
*Proposed Fix:* Force spawn keybearer enemies when keydoors present?
*Bug:* Preslayer rooms in Knossos can sometimes soft-lock players if the 1st room is a full key-door room. Having maximum keys from RandomUrns is a workaround. \
*Proposed Fix:* N/A

*Bug:* Knossos can sometimes generate dead ends when placed above a large. (Rare, and not a game-breaking bug.) \
*Proposed Fix:* N/A

*Bug:* Some Preslayer Hell and Cave floors can spawn bosses before the room is locked. This is manageable in Caves, but on Hell floors it can be unfair, as players may have to fight 4-5 Eye Bosses on a single floor. \
*Proposed Fix:* Remove spawn markers/force despawn the preset enemies.

*Bug:* Ducks Mods on the welcome screen display incorrect text. \
*Proposed Fix:* Localization issue, can likely override widget.

## Mod Suggestions (no order):
- Fifth Player. (Working pre-build in testing)
- Lich balls should be able to damage enemies as well (currently they only damage towers).
- Add new ball effects such as Confusion, Stealth, Charm, and Slow.
- Increase Eye Boss threat range.
- Players able to swap in game between all 3 potion abilities.
- When a player dies, revive them as Lazy for the next floor only, or revive them as Lazy forever.
- When a player loots any gold on this floor he instand became lazy for this floor.
- Add more death bosses.
- Knossos without extra rooms. (No branching, normal gen, but with the extra rooms.)
- Option to enable/disable island rooms in Knossos.
- Option for Knossos to generate more linear room layouts.
- Ability to save mod settings layouts in-game. (settings.json)

## Self-Suggestions:
- Meteors that follow player and keep dropping non-stop. (Like MeteorStorm from Super Stardust)

## Outside Modding: 
- Custom levels: Caves level that spirals downwards to unlock a massive elevator in the middle that brings to surface where a boss is?
