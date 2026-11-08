# CHANGELOG

One dated entry per prompt/task: a few lines on what changed, plus any deviations or open issues. Newest first.
The code is the source of truth (see CLAUDE.md): where an entry says "deviation", the code keeps that behaviour on purpose.
Full current behaviour lives in STATE.md.

## 2026-11-08: Friendly explosions, Firecracker, Spitter, Speedo
- Player explosions and implosions (figures, Blastoid rockets, Short Fuse / Magnet implosions, Bomb Drop) now never push ANY player figure, on deck or on the board: `Figure.blast_immune` is true for every player victim of a player-side blast. Enemy explosions still push player figures and enemies' own explosions still affect enemies.
- Firecracker: its team-immunity aura is now enemy-only (`grants_explosion_immunity` is true only for enemy Firecrackers, so enemy explosion builds such as Powder Keg still work; the orange ring shows on enemies only). Its other abilities are unchanged. The AI no longer gets `firecracker_target_bonus` for player Firecrackers (they shield nothing now). Description updated.
- Spitter: spraying no longer uses its action. Release leaves it selected and flickable: spray first, then flick, or skip, or spray again. Enemy Spitters spray first and then take their normal flick (`spray_point` is attached to the chosen flick; with nothing to flick a good spray is the whole turn).
- Speedo: flick power 0.75 -> 0.525 (`flick_power_multiplier` in `speedo.tres`).
- Open issue: the player's Spitter can spray repeatedly in one turn until its water is gone (no cap on sprays per turn).

## 2026-11-09: Duplicates, 3 figure choices, flatter rarity curve
- Duplicate figures: choosing (reward), buying (shop) or being offered (Trader) a figure you already own gives a Recruit / Upgrade choice. Recruit = the usual flow (pick which figure it replaces). Upgrade = an Upgrade step on your existing copy (pick which copy if you have several; both paths shown). Upgrade is disabled with a note when your copy has no tiers left. The shop charges the listed price for either; the Trader's Upgrade still takes the given figure(s) and money but you get the upgrade step instead of the new figure (interpretation: the trade cost stays the same). "Owned" badge on offered figures (reward cards, shop cards, Trader medium card; the high trade text says "[owned]").
- Figure rewards: 3 choices in every act (`figure_choices_by_act` [3, 3, 3]); the bonus item steps (0 / 1 / 2) are unchanged. Elite fights use the same array, so they also offer 3 (they used 3 / 2 / 1 before); Trophy Case still +1, Ascension 6 still caps at 2.
- Rarity per slot (Common / Uncommon / Rare): act 1 75 / 22 / 3, act 2 60 / 32 / 8, act 3 50 / 38 / 12 (`rarity_weights_by_act`; the shop's figure rolls use the same weights). Elite (60 / 35 / 5) and boss (Rare only) picks unchanged.
- Headless-checked: Owned flags, the choice screen and its disabled state, copy picking, shop upgrade tree, Trader medium trade with an owned figure.

## 2026-11-08: Upgrade trees
- Replaced the single figure-specific upgrade with UPGRADE TREES: every draftable figure has two paths of three tiers (180 upgrades, `resources/upgrades/<figure>/`, `UpgradeTree` + `UpgradeData`, all numbers and text editable in the .tres). Tiers in order; the first pick locks the other path; lost if the figure is replaced; finishes stay separate. Full table in STATE.md.
- Getting upgrades: new "Upgrade" reward step (pick a figure, then a tier on a path; both paths shown until the first pick), elites 1, bosses 1 finish + 2 Upgrades (replacing the old finish-or-upgrade step), bonus items can roll an Upgrade (instead of upgrade_item), shop Upgrades $5 / $8 / $12 by tier (2 offers, before Ascension markups), the Trader's high trade grants an Upgrade step. Numbers in RewardConfig / ShopConfig.
- Enemies: Ascension 1 enemy upgrades roll tier 1 on a random path; from Ascension 5 elite and boss enemies can roll tier 2; Mirror Match copies the tiers. UI: tree view in the Inventory figure details, the Compendium figure page and the reward step; gold pips per tier on figures and the deck strip.
- Saves: `deck_upgrade_state`; old single upgrades migrate to tiers (and fill the lower tiers of their path).
- Implemented with new `@export`s on the abilities plus generic hooks (dealt-knockback bonus, enemy auras, tap abilities for self / point taps, bonus-flick queue, run modifiers); the enemy AI uses tap abilities (Magnet push / implode, Absorber spit, Ghost teleport) and plans with ability flick-power multipliers. Old testing Upgrades screen removed. `tools/smoke_test.gd` checks every tree.
- Interpretations and gaps: see STATE.md "Upgrade trees: interpretations and gaps". Headless-tested: every tree loads, 60 figures with tier 3 spawn and run, the path / lock API, Magnet push, Absorber spit, Pinhead / Engineer / Alchemist multi-placements, Ghost teleport; NOT playtested.

## 2026-11-05: Rarity, Absorber, Cluster body, Bummer vs bosses, Juicer Douse
- Rarity: Absorber Rare -> Uncommon, Spitter Uncommon -> Common. Absorber damping multiplier 1.4 -> 1.1 (about 25% farther flicks; mass and flick power unchanged).
- Cluster is now really 3 small units in one rigid body: one circle collision shape (radius 45) per clustling in a tight triangle (diamond for Big Bunch's 4), each drawn as its own little figure, rotation locked. A toss removes the nearest clustling's circle (the body re-centres) and a rejoining clustling takes the free spot nearest where it touched (a full cluster refuses it). Toss speed 700 -> 950. New hooks `draws_own_label`, `Figure.use_custom_shapes()`; `accept_rejoin` now takes the touch position. The FigureData radius is 97 (bounding circle of the three).
- Bummer vs boss bodies: a taken-over boss body now flicks at 25% power (`takeover_boss_power_cap`) and only with shots that stop at least 1.5 x its radius + 150 px from every edge (`takeover_boss_edge_factor`, `takeover_boss_safety_margin`); among those it prefers moving away from the Bummer and can still hit allies; with no safe shot it passes (`{pass: true}`, a wasted flick). Checked headless with a Bummer beside Trangle, Slime, Skull-o-tron, The Wall and Mad Creator: at all four test spots near edges they pass, in open space they move 100-240 px/s and stay on the table. The Mad Creator's own in-box flick is not a takeover and is unchanged.
- Juicer: opposing figures touching its trail or splash pieces (moving or resting) get a light Douse, +20% knockback for 2 rounds (`douse_rounds`, `douse_knockback` on the ability), refreshed on contact, not stacking. It shares the Doused status with Alchemist: only the stronger multiplier applies (Alchemist 1.5 replaces the juice version, never the reverse) and the juice has a lighter green tint. AI: `juice_path_penalty` 25 per player juice piece on a shot path, `juice_push_bonus` 30 per own juice piece the target's slide crosses (both capped at 3 pieces). Description updated.
- Open issues: a boss next to a Bummer near an edge never moves (it passes every flick while the aura holds it); Cluster/Absorber visuals and the Spitter/Juicer tints only checked headless.

## 2026-11-04: Cluster, Spitter, Absorber
- Three new draftable figures (both sides), each with a figure-specific upgrade, placeholder colors / labels (CL, SP, AB) / icons (CLUSTER, SPRAYER, MAW). Details in STATE.md section 3.
- Cluster (Uncommon): one body of 3 clustlings (mass 2.2); a tap tosses one out as a fresh flickable figure (toss OR flick; never the last); loose clustlings rejoin their cluster on contact; only the cluster pays income. Big Bunch: 4 clustlings. AI tosses at player figures and walks loose clustlings home.
- Spitter (Uncommon): press and hold 0.25 s to spray toward the finger (spray OR flick), 4 s of water per combat, shrinks to 50% when empty, blue water arc. Big Gulp: bigger, 6 s of water. AI sprays player figures toward the edge for 1.6 s.
- Absorber (Rare, radius 66): its own flick hitting a smaller opposing figure at >= 300 px/s absorbs it; the victim shrinks over 3 rounds then counts as knocked off; a teammate's hit >= 500 px/s frees it. Big Belly: radius 80. AI aims at smaller player figures and at an Absorber holding an ally.
- Supporting changes: `Figure.shed` pieces can carry `flickable` and `on_spawn`; `Main.retire_figure / absorb_figure / finish_absorbed / release_absorbed`; new ability hooks (`get_toss_stats`, `accept_rejoin`, `get_rejoin_target`, `get_spray_stats`, `set_spray`, `get_absorb_speed`, `get_escape_speed`, `get_held_figure`); `Figure.deck_slot` (Costume Change no longer relies on the `_players` order, which Splitter minis and tossed clustlings change).
- Values chosen: Spitter drop impulse 20 at 20 drops/s (lower values do not move a resting figure at all because of the stop-speed settle rule); a 3 s spray slides a resting mass-1 figure about 280 px. Cluster radius formula 45 x (1 + 0.45 sqrt(n-1)) (74 for three).
- Deviations / open issues: a figure being absorbed leaves play at once (the last enemy absorbed wins immediately; the kill is counted when it is fully shrunk, and not at all if the fight ends first); Rewind restores an absorbed figure from the snapshot but the old hidden copy stays unused; the Spitter's "spray incoming lanes" is simplified to spraying player figures toward the edge; the AI does not toss to block lanes; Cluster/Spitter/Absorber only tested headless (no device).

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
