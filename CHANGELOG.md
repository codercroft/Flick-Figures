# CHANGELOG

One dated entry per prompt/task: a few lines on what changed, plus any deviations or open issues. Newest first.
The code is the source of truth (see CLAUDE.md): where an entry says "deviation", the code keeps that behaviour on purpose.
Full current behaviour lives in STATE.md.

## 2026-11-04: Playtest changes (Blastoid, Rally, Ascension 4, relics)
- Blastoid: rocket explosion force 800 -> 1200 (radius still 170). When a Firecracker's hit (or any "set off explosives" effect) detonates it, it now fires a rocket at the nearest opposing figure on the table and stays put (keeps its action) instead of exploding in place. New upgrade Twin Rockets (`rockets_per_shot` 2): a tap fans the 2 rockets 6 degrees either side of the tapped point (`spread_degrees`, @export); a detonation sends one at each of the 2 nearest opposing figures (the same one if only one is left). Description updated. AI: a set-off Blastoid is valued as the blast at the nearest player figure(s).
- Rally: each teammate (board and deck) is now nudged toward ITS OWN nearest opposing figure at the same `nudge_speed` 440 (forward if no opponent is left). New upgrade Rallying Cry (`resets_cycle`): also makes every other teammate flickable again (Rally itself is not recharged, so it cannot loop alone: deviation from "every figure"). AI: `_rally_value` adds `rally_ally_bonus` (15) per teammate whose aimed nudge heads at a player figure and stays on the table.
- Ascension 4: Cha-ching nerf removed completely (`cha_ching_reduction` and its plumbing gone); shop prices x1.5 rounded up (was x1.2).
- Relics: Second Wind is now Boss rarity (boss rewards only). New Common relic Costume Change: equip, unequip and swap equipment in the Inventory during combat, on your own idle turn (Main.can_swap_equipment: PLAYER_TURN, no bonus flick pending); no flick is used and effects apply at once (`Figure.set_equipment` re-applies mass, damping, bounce and the effect). Reordering stays locked in combat.
- Checked headless: live equip/unequip mass, 1/2 rockets on detonate and tap, Rallying Cry recharge, lock outside the player's turn.
- Open issues: swapping equipment resets that item's per-combat state (e.g. a used Parachute); Rally's aimed nudge is only modelled roughly by the AI.

## 2026-11-04: Audit, STATE.md, CHANGELOG.md, CLAUDE.md refresh
- Wrote STATE.md from the code and resource files (rules, map, rewards, shop, every figure/relic/power/equipment/finish/upgrade, arenas, encounters, elites, bosses, AI, Ascension, events, screens, known issues).
- Added this CHANGELOG.md and the standing "sync" rules to CLAUDE.md; refreshed its game summary and fixed stale lines (top bar, run info, shop picker, encounter counts).
- Fixes found by the audit: Pinhead and Engineer descriptions said the opposite of what they do (both can place AND flick; turrets fire on both turns); `RunManager._roll_enemy_gear` read `RunConfig.enemy_gear` instead of `AscensionConfig.gear` (same resource, now reads the Ascension one).
- Deviations/open issues: see STATE.md section 12 (Pinball Wizard uses Corner Posts, Ascension 5 act 1 elites get no gear, Cha-ching kill bonus is $0 at Ascension 4, 5-figure encounters are trimmed to 4 below Ascension 3, shops/events start in the 4th row, Ascension 10 has no save between the two bosses).

## 2026-11-03: Top bar, Map and Inventory screens
- Top bar: Map, Inventory, sound, "Act n/3 Row r An", money (relic icons and the "i" button removed). Map = view-only overlay. Inventory = full screen: roster along the bottom (reorder outside combat), details box, tabs Equipment (drag to equip, tap badge to unequip), Powers (Discard + confirm, also in combat), Relics. Old run-info tabs removed.
- Deviation: removed the map's Equipment button (Inventory replaces it); `equip.tscn` left unlinked. Open issue: drag-and-drop not tried with a real finger.

## 2026-11-03: Ascension system
- `AscensionConfig` (levels 0-10), flat Ascension 0 (4 enemies, no act multiplier, no random enemy gear, no elite boost/gear/relic), unlock progress saved, selector before New Run, level in top bar/history/save, per-level win stats.
- Deviations: encounter lineups above 4 are trimmed at Ascension 0-2; Ascension 4 removes Cha-ching's kill bonus entirely; encounter-forced gear stays at level 0.

## 2026-11-03: Splitter minis and Bummer vs bosses
- Mini flick power x0.7, knockback dealt x0.75 (size/mass unchanged). New `boss_body` tag; Bummer takeover shots of boss bodies are scored never to knock themselves off (heavy penalty, reward for moving away).

## 2026-11-03: Explosion changes
- Player-side explosions never push the player's on-deck figures. Firecracker makes its whole team immune to its own team's explosions (orange ring; AI aware, bonus for hitting a player Firecracker).

## 2026-11-03: Alchemist revert, roster at the bottom, Magnet Throw
- Alchemist placing uses its action again (enemy Alchemist too). Roster row moved to the bottom of the Roster tab. Magnet Throw radius 450 -> 225.

## 2026-11-03: Splitter common, Magnet implosion, Blastoid, roster/deck order, elite rarity
- Splitter Common. Magnet implodes when knocked off (stronger with Short Fuse). Blastoid shot has no range cap; Glow-in-the-dark now scales its blast. Roster is a deck strip with drag-to-reorder (saved with the run); reward/shop pickers use it. Elite figure choices roll 60/35/5.

## 2026-11-03: Bloodluster, Juicer, Pinball Wizard
- Bloodluster bonus flicks add +35% damping stacks (pips + tint, reset each round). Juicer trail/splash only affect opponents and the trail points back. Pinball Wizard = Crazy Man + 2 Speedos on Corner Posts (deviation: "corner walls" read as Corner Posts).

## 2026-11-02: Elite overhaul
- 13 elites by act, `EliteConfig`, enemy relics (7), act 3 elite relic choice, AI tricks (Glue chains, Eater feeding, Engineer opening turret), Well-Rounded Squad and Fireworks moved to the regular pool.

## Earlier history (reconstructed from git log; no per-prompt notes were kept)
- 2026-10-30 to 2026-11-02: Duwall shell, Piggy Bank, Shieldon Ooper, Alchemist, Blastoid, Energizer, Eater, Bloodluster, Bummer takeover, Glue Guy chains, boss rework (Slime, Skull-o-tron), web/iPhone deploy, balance passes.
- 2026-10-31: AudioManager and placeholder sounds, main menu and run saving, run history/Compendium, Trangle and Mad Creator, Aggro-bom, Starter Walls, Alchemist Douse, placement rules.
- 2026-11-01: Engineer turrets on both turns, Ghost Full Haunt limit, Pusher uncommon, Trangle back wall.
