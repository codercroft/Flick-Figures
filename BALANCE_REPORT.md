# Balance report

Generated 2026-11-16 22:43 from commit `6b7c5d3`. Everything below is the game as it is: the sims change no balance value, figure or enemy behaviour.

**How to read it.** The bot plays the player side with the enemy AI's own shot evaluation (elite search depth, aim accuracy 0.85), fights use fixed seeds, Ascension 0 unless noted. Win rates come with a 95% interval (Wilson); with few fights per matchup treat differences under about 10 points as noise.

## Summary: the biggest outliers

- Figures (sim 1) well above the rest (mean 44%): Blastoid 64%.
- Figures (sim 1) well below the rest (mean 44%): Speedo 24%, Ghost 29%.
- Regular encounters (sim 1) well above the rest (mean 44%): Bent Lane (act 1) 72%, Sticky Situation (act 2) 70%.
- Regular encounters (sim 1) well below the rest (mean 44%): Ghost Patrol (act 2) 8%, Bodyguards (act 1) 16%.
- Upgrade paths (sim 2) well above the rest (mean 53%): Engineer Turret 94%, Piggy Bank Hoard 94%, Duwall Ram 91%, Ghost Haunt 88%.
- Upgrade paths (sim 2) well below the rest (mean 53%): Shieldon Ooper Spikes 19%.
- Biggest tier-3 gains over the plain figure: Ghost Haunt +58 pts, Piggy Bank Hoard +46 pts, Engineer Turret +42 pts. Smallest (or negative): Blastoid Nuke -31 pts, Pusher Drive -18 pts, Absorber Spit -17 pts.
- Regular encounters (sim 3) well above the rest (mean 76%): Glass Cannons 94%.
- Regular encounters (sim 3) well below the rest (mean 76%): Bodyguards 56%, Well-Rounded Squad 56%, Ghost Patrol 56%.
- Elites (sim 3) well above the rest (mean 64%): Swarm 96%, Pinball Wizard 92%.
- Elites (sim 3) well below the rest (mean 64%): The Collector 22%, Siege 30%.
- Bosses (sim 3) well above the rest (mean 32%): Sniper Squad 58%, Slime 56%.
- Toughest elites / bosses for these decks: Mad Creator 14%, The Wall 16%, Skull-o-tron 22%.
- Enemy figures that knock off the most player figures overall: (own side) (1089), Grunt (637), Duwall (403), Ghost (243), Trangle (176). `(own side)` means the figure fell during the player's OWN flick (the bot's shot knocked off or slid off one of its own figures).
- Full runs at Ascension 0: 0% won (0 of 200, CI 0%-2%).
- Ascension 0: most runs end against Grunts only (131 of 200 deaths).
- Full runs at Ascension 5: 0% won (0 of 100, CI 0%-4%).
- Ascension 5: most runs end against Grunts only (58 of 100 deaths).

## Bugs and oddities found during the sims

- Sim 1: **stalemates**: 18 of 2418 fights had no result after 300 simulated seconds (about 55 turns; a normal fight is 10-30 turns), counted as losses. The game has no turn limit. Most often vs Sticky Situation (Mud Flats) x8, Demolition Crew (Pinball) x2, Speed Trap (Speedway) x2, Ghost Patrol (Open Field) x1, Glass Cannons (Pinball) x1; typical reports are 1 player vs 1 enemy figure that cannot hurt each other (a Glue Guy, a Shieldon wall, Mud Flats...).
- Sim 1: in 4 fights the last enemy fell AFTER the game's win check (e.g. a delayed explosion such as Sneaky Bomber's), so the fight went on to another player turn and only ended when the player flicked once more. Harmless, but a needless extra turn.
- Sim 2: "softlock: no player figure is left, but the combat never declared the loss (it waits for a flick nobody can make)" in 1 fights (first seen: Rally Charge vs Sticky Situation).
- Sim 2: **stalemates**: 13 of 1984 fights had no result after 300 simulated seconds (about 55 turns; a normal fight is 10-30 turns), counted as losses. The game has no turn limit. Most often vs Sticky Situation (Mud Flats) x8, Fortress (Fortress Walls) x5; typical reports are 1 player vs 1 enemy figure that cannot hurt each other (a Glue Guy, a Shieldon wall, Mud Flats...).
- Sim 2: in 9 fights the last enemy fell AFTER the game's win check (e.g. a delayed explosion such as Sneaky Bomber's), so the fight went on to another player turn and only ended when the player flicked once more. Harmless, but a needless extra turn.
- Sim 2: the bot found no shot worth taking and used its fallback nudge 138 times in 1984 fights.
- Sim 3: **stalemates**: 48 of 1650 fights had no result after 300 simulated seconds (about 55 turns; a normal fight is 10-30 turns), counted as losses. The game has no turn limit. Most often vs Siege (Fortress Walls) x15, Shield Wall (Side Rails) x4, Shield Wall (Whirlpool) x3, Shield Wall (Open Corners) x3, Bodyguards (Side Rails) x2; typical reports are 1 player vs 1 enemy figure that cannot hurt each other (a Glue Guy, a Shieldon wall, Mud Flats...).
- Sim 3: in 15 fights the last enemy fell AFTER the game's win check (e.g. a delayed explosion such as Sneaky Bomber's), so the fight went on to another player turn and only ended when the player flicked once more. Harmless, but a needless extra turn.
- Sim 3: the bot found no shot worth taking and used its fallback nudge 16531 times in 1650 fights.
- Sim 1 log (x147): `[settle] waiting N.Ns, still moving: Grunt Npx/s`
- Sim 1 log (x49): `[settle] waiting N.Ns, still moving: Pinhead Npx/s`
- Sim 1 log (x33): `WARNING: [settle] forced after N.Ns, still moving: Grunt Npx/s`
- Sim 1 log (x33): `[settle] forced after N.Ns, still moving: Grunt Npx/s`
- Sim 1 log (x33): `[settle] waiting N.Ns, still moving: Speedo Npx/s`
- Sim 1 log (x21): `[settle] waiting N.Ns, still moving: Juicer Npx/s`
- Sim 1 log (x16): `[settle] waiting N.Ns, still moving: Powerhouse Npx/s`
- Sim 1 log (x13): `[settle] waiting N.Ns, still moving: Magnet Npx/s`
- Sim 2 log (x153): `[settle] waiting N.Ns, still moving: Grunt Npx/s`
- Sim 2 log (x54): `[settle] waiting N.Ns, still moving: Pinhead Npx/s`
- Sim 2 log (x42): `WARNING: [settle] forced after N.Ns, still moving: Grunt Npx/s`
- Sim 2 log (x42): `[settle] forced after N.Ns, still moving: Grunt Npx/s`
- Sim 2 log (x35): `[settle] waiting N.Ns, still moving: Speedo Npx/s`
- Sim 2 log (x29): `[settle] waiting N.Ns, still moving: Juicer Npx/s`
- Sim 2 log (x22): `[settle] waiting N.Ns, still moving: Magnet Npx/s`
- Sim 2 log (x17): `[settle] waiting N.Ns, still moving: Grunt Npx/s, Pinhead Npx/s`
- Sim 3 log (x30): `[settle] waiting N.Ns, still moving: Grunt Npx/s`
- Sim 3 log (x30): `ERROR: Resumed function '_wait_until_settled_inner()' after await, but class instance is gone. At script: res://scripts/main.gd:N`
- Sim 3 log (x29): `[settle] waiting N.Ns, still moving: Speedo Npx/s`
- Sim 3 log (x29): `[settle] waiting N.Ns, still moving: Ghost Npx/s`
- Sim 3 log (x28): `[settle] waiting N.Ns, still moving: Powerhouse Npx/s, Pusher Npx/s`
- Sim 3 log (x28): `WARNING: [settle] forced after N.Ns, still moving: Powerhouse Npx/s, Pusher Npx/s`
- Sim 3 log (x28): `[settle] forced after N.Ns, still moving: Powerhouse Npx/s, Pusher Npx/s`
- Sim 3 log (x25): `[settle] waiting N.Ns, still moving: Magnet Npx/s`
- Sim 4_a0 log (x9): `[settle] waiting N.Ns, still moving: Grunt Npx/s`
- Sim 4_a0 log (x9): `[shop] building offers from N item types`
- Sim 4_a0 log (x9): `[shop]   Swap a figure -> N offers ["Swap a figure"]`
- Sim 4_a0 log (x9): `[shop] N offers in total`
- Sim 4_a0 log (x7): `[settle] waiting N.Ns, still moving: Grunt Npx/s, Grunt Npx/s`
- Sim 4_a0 log (x4): `WARNING: [settle] forced after N.Ns, still moving: Grunt Npx/s`
- Sim 4_a0 log (x4): `[settle] forced after N.Ns, still moving: Grunt Npx/s`
- Sim 4_a0 log (x3): `[shop]   Upgrades for sale -> N offers ["Upgrade", "Finish: Glow-in-the-dark"]`
- Sim 4_a5 log (x10): `[settle] waiting N.Ns, still moving: Grunt Npx/s`
- Sim 4_a5 log (x3): `[settle] waiting N.Ns, still moving: Grunt Npx/s, Grunt Npx/s`
- Sim 4_a5 log (x1): `[settle] waiting N.Ns, still moving: Powerhouse Npx/s, Grunt Npx/s`
- Sim 4_a5 log (x1): `[shop] building offers from N item types`
- Sim 4_a5 log (x1): `[shop]   Figures for sale -> N offers ["Ghost", "Magnet", "Aggro-bom"]`
- Sim 4_a5 log (x1): `[shop]   Swap a figure -> N offers ["Swap a figure"]`
- Sim 4_a5 log (x1): `[shop]   Relics for sale -> N offers ["Relic: Home Field (Common)"]`
- Sim 4_a5 log (x1): `[shop]   Powers for sale -> N offers ["Power: Bomb Drop"]`

## Sim 1: figure strength (figure + 3 Grunts vs each act's regular encounters, Ascension 0)

The average figure here wins 44% of its fights.

| Figure | Fights | Win rate | 95% CI | Figures lost | Player turns | Act 1 | Act 2 | Act 3 |
|---|---|---|---|---|---|---|---|---|
| Blastoid | 78 | 64% | 53%-74% | 2.81 | 8.3 | 57% | 77% | 56% |
| Duwall | 78 | 58% | 47%-68% | 3.23 | 10.2 | 53% | 50% | 78% |
| Bummer | 78 | 58% | 47%-68% | 2.78 | 6.9 | 53% | 60% | 61% |
| Bloodluster | 78 | 58% | 47%-68% | 3.17 | 9.1 | 50% | 60% | 67% |
| Absorber | 78 | 55% | 44%-66% | 3.06 | 8.2 | 37% | 67% | 67% |
| Sneaky Bomber | 78 | 54% | 43%-64% | 3.06 | 8.4 | 53% | 50% | 61% |
| Engineer | 78 | 51% | 40%-62% | 3.05 | 8.5 | 50% | 60% | 39% |
| Eater | 78 | 51% | 40%-62% | 3.14 | 7.3 | 57% | 40% | 61% |
| Crazy Man | 78 | 50% | 39%-61% | 3.24 | 7.0 | 60% | 47% | 39% |
| Land Miner | 78 | 50% | 39%-61% | 3.10 | 8.1 | 63% | 40% | 44% |
| Rally | 78 | 50% | 39%-61% | 3.24 | 7.2 | 47% | 50% | 56% |
| Bombo | 78 | 47% | 37%-58% | 3.18 | 7.8 | 40% | 60% | 39% |
| Bumper | 78 | 46% | 36%-57% | 3.46 | 10.6 | 37% | 57% | 44% |
| Pusher | 78 | 44% | 33%-55% | 3.41 | 8.1 | 30% | 43% | 67% |
| Piggy Bank | 78 | 44% | 33%-55% | 3.37 | 14.8 | 37% | 57% | 33% |
| Juicer | 78 | 44% | 33%-55% | 3.40 | 7.5 | 40% | 33% | 67% |
| Wikka Wat | 78 | 44% | 33%-55% | 3.29 | 7.4 | 37% | 53% | 39% |
| Powerhouse | 78 | 41% | 31%-52% | 3.44 | 7.2 | 33% | 47% | 44% |
| Cha-ching | 78 | 41% | 31%-52% | 3.38 | 8.5 | 43% | 47% | 28% |
| Spitter | 78 | 41% | 31%-52% | 3.46 | 8.0 | 33% | 37% | 61% |
| Pinhead | 78 | 40% | 30%-51% | 3.40 | 8.2 | 43% | 33% | 44% |
| Cluster | 78 | 40% | 30%-51% | 3.85 | 10.2 | 27% | 53% | 39% |
| Glue Guy | 78 | 38% | 28%-50% | 3.37 | 13.6 | 30% | 57% | 22% |
| Energizer | 78 | 37% | 27%-48% | 3.31 | 7.9 | 27% | 47% | 39% |
| Shieldon Ooper | 78 | 36% | 26%-47% | 3.53 | 11.3 | 43% | 33% | 28% |
| Alchemist | 78 | 36% | 26%-47% | 3.44 | 8.9 | 33% | 47% | 22% |
| Splitter | 78 | 35% | 25%-46% | 4.15 | 11.2 | 40% | 37% | 22% |
| Magnet | 78 | 32% | 23%-43% | 3.67 | 8.5 | 30% | 30% | 39% |
| Aggro-bom | 78 | 31% | 22%-42% | 3.53 | 7.6 | 30% | 33% | 28% |
| Ghost | 78 | 29% | 21%-40% | 3.55 | 7.3 | 30% | 20% | 44% |
| Speedo | 78 | 24% | 16%-35% | 3.63 | 8.9 | 30% | 23% | 17% |


Regular encounters, hardest first (win rate averaged over every figure):

| Encounter | Act | Fights | Win rate |
|---|---|---|---|
| Ghost Patrol | 2 | 186 | 8% |
| Bodyguards | 1 | 186 | 16% |
| Well-Rounded Squad | 1 | 186 | 26% |
| Fortress | 3 | 186 | 35% |
| Demolition Crew | 3 | 186 | 37% |
| Pushover | 1 | 186 | 39% |
| Tinderbox | 2 | 186 | 42% |
| Glass Cannons | 1 | 186 | 53% |
| The Setup | 2 | 186 | 54% |
| Fireworks | 2 | 186 | 59% |
| Speed Trap | 3 | 186 | 63% |
| Sticky Situation | 2 | 186 | 70% |
| Bent Lane | 1 | 186 | 72% |

## Sim 2: upgrade paths at tier 3 (figure + 3 Grunts vs act 2 and 3 regular encounters)

`Change` is the win rate minus the same figure with no upgrade against the same acts in sim 1 (blank if sim 1 was not run).

| Figure path | Fights | Win rate | 95% CI | Change vs no upgrade | Figures lost | Player turns |
|---|---|---|---|---|---|---|
| Ghost Haunt | 32 | 88% | 72%-95% | +58 pts | 2.62 | 10.1 |
| Piggy Bank Hoard | 32 | 94% | 80%-98% | +46 pts | 2.75 | 11.7 |
| Engineer Turret | 32 | 94% | 80%-98% | +42 pts | 1.44 | 5.0 |
| Land Miner Smart Bombs | 32 | 78% | 61%-89% | +36 pts | 2.22 | 5.0 |
| Piggy Bank Spender | 32 | 84% | 68%-93% | +36 pts | 2.91 | 10.9 |
| Duwall Ram | 32 | 91% | 76%-97% | +30 pts | 2.69 | 8.8 |
| Alchemist Brew | 32 | 66% | 48%-80% | +28 pts | 2.72 | 7.1 |
| Speedo Zip | 32 | 47% | 31%-64% | +26 pts | 3.31 | 8.2 |
| Land Miner Multi-Mine | 32 | 66% | 48%-80% | +24 pts | 2.50 | 6.5 |
| Bombo Boom | 32 | 72% | 55%-84% | +20 pts | 2.34 | 6.4 |
| Aggro-bom Fuse | 32 | 50% | 34%-66% | +19 pts | 3.19 | 7.5 |
| Absorber Gut | 32 | 84% | 68%-93% | +18 pts | 2.56 | 10.0 |
| Ghost Phase | 32 | 47% | 31%-64% | +18 pts | 3.12 | 7.7 |
| Speedo Dash | 32 | 38% | 23%-55% | +17 pts | 3.41 | 10.3 |
| Aggro-bom Rage | 32 | 47% | 31%-64% | +16 pts | 3.31 | 8.1 |
| Powerhouse Might | 32 | 59% | 42%-74% | +14 pts | 3.06 | 8.2 |
| Bombo Shrapnel | 32 | 66% | 48%-80% | +14 pts | 2.84 | 8.0 |
| Bumper Spring | 32 | 66% | 48%-80% | +14 pts | 3.16 | 10.1 |
| Engineer Tech | 32 | 66% | 48%-80% | +14 pts | 2.12 | 6.9 |
| Alchemist Potency | 32 | 50% | 34%-66% | +12 pts | 2.94 | 10.3 |
| Duwall Shell | 32 | 72% | 55%-84% | +11 pts | 3.03 | 10.5 |
| Sneaky Bomber Fuse | 32 | 66% | 48%-80% | +11 pts | 2.34 | 6.0 |
| Sneaky Bomber Stealth | 32 | 66% | 48%-80% | +11 pts | 2.66 | 7.6 |
| Powerhouse Grit | 32 | 56% | 39%-72% | +10 pts | 2.97 | 7.6 |
| Crazy Man Hype | 32 | 53% | 36%-69% | +9 pts | 2.94 | 10.3 |
| Glue Guy Tar | 32 | 53% | 36%-69% | +9 pts | 3.12 | 10.6 |
| Cluster Swarm | 32 | 56% | 39%-72% | +8 pts | 3.91 | 11.3 |
| Magnet Field | 32 | 41% | 26%-58% | +7 pts | 3.50 | 7.8 |
| Cha-ching Savings | 32 | 47% | 31%-64% | +7 pts | 3.31 | 9.2 |
| Crazy Man Frenzy | 32 | 50% | 34%-66% | +6 pts | 2.84 | 9.5 |
| Splitter Brood | 32 | 38% | 23%-55% | +6 pts | 6.09 | 13.4 |
| Shieldon Ooper Bulwark | 32 | 38% | 23%-55% | +6 pts | 3.50 | 15.0 |
| Magnet Collapse | 32 | 38% | 23%-55% | +4 pts | 3.38 | 6.8 |
| Juicer Slick | 32 | 50% | 34%-66% | +4 pts | 3.25 | 7.6 |
| Bumper Bulk | 32 | 56% | 39%-72% | +4 pts | 3.28 | 10.2 |
| Splitter Shrapnel | 32 | 34% | 20%-52% | +3 pts | 4.22 | 8.3 |
| Pinhead Bumper Pins | 32 | 41% | 26%-58% | +3 pts | 3.41 | 8.8 |
| Blastoid Artillery | 32 | 72% | 55%-84% | +3 pts | 2.31 | 9.1 |
| Bloodluster Predator | 32 | 66% | 48%-80% | +3 pts | 3.09 | 8.8 |
| Bummer Downer | 32 | 62% | 45%-77% | +2 pts | 3.00 | 10.2 |
| Juicer Squeeze | 32 | 47% | 31%-64% | +1 pts | 3.12 | 7.7 |
| Eater Appetite | 32 | 47% | 31%-64% | -1 pts | 3.09 | 7.6 |
| Cluster Rebound | 32 | 47% | 31%-64% | -1 pts | 4.09 | 9.8 |
| Cha-ching Bounty | 32 | 38% | 23%-55% | -2 pts | 3.44 | 7.4 |
| Spitter Firehose | 32 | 44% | 28%-61% | -2 pts | 3.38 | 9.1 |
| Pusher Shove | 32 | 50% | 34%-66% | -2 pts | 3.25 | 8.1 |
| Pinhead Pin Count | 32 | 34% | 20%-52% | -3 pts | 3.56 | 9.9 |
| Bummer Gloom | 32 | 56% | 39%-72% | -4 pts | 2.53 | 7.0 |
| Energizer Charge | 32 | 38% | 23%-55% | -6 pts | 3.53 | 9.9 |
| Energizer Shock | 32 | 38% | 23%-55% | -6 pts | 3.47 | 8.2 |
| Bloodluster Frenzy | 32 | 53% | 36%-69% | -9 pts | 3.31 | 11.8 |
| Eater Digest | 32 | 38% | 23%-55% | -10 pts | 3.19 | 7.5 |
| Spitter Sprinkler | 32 | 34% | 20%-52% | -11 pts | 3.62 | 8.4 |
| Rally Formation | 32 | 41% | 26%-58% | -11 pts | 3.19 | 7.0 |
| Glue Guy Sticky | 32 | 31% | 18%-49% | -12 pts | 3.25 | 15.3 |
| Shieldon Ooper Spikes | 32 | 19% | 9%-35% | -12 pts | 3.72 | 12.9 |
| Wikka Wat Scratch | 32 | 34% | 20%-52% | -14 pts | 3.34 | 7.3 |
| Wikka Wat Seek | 32 | 34% | 20%-52% | -14 pts | 3.47 | 7.6 |
| Rally Charge | 32 | 38% | 23%-55% | -15 pts | 3.44 | 7.6 |
| Absorber Spit | 32 | 50% | 34%-66% | -17 pts | 3.25 | 9.2 |
| Pusher Drive | 32 | 34% | 20%-52% | -18 pts | 3.56 | 8.5 |
| Blastoid Nuke | 32 | 38% | 23%-55% | -31 pts | 3.56 | 8.1 |

## Sim 3: mid-run decks vs encounters, elites and bosses

Decks (edit them in `tools/balance/decks.json`): Blasters, Bruisers, Control, Skirmishers, Tricksters.

| Deck | Fights | Win rate | 95% CI | Figures lost | Player turns |
|---|---|---|---|---|---|
| Bruisers | 330 | 71% | 66%-76% | 2.48 | 16.0 |
| Blasters | 330 | 70% | 65%-75% | 1.99 | 6.4 |
| Control | 330 | 58% | 53%-63% | 2.59 | 13.8 |
| Skirmishers | 330 | 42% | 36%-47% | 3.25 | 11.3 |
| Tricksters | 330 | 73% | 68%-77% | 3.49 | 14.7 |


Win rate of each deck against every target. `Turns` is player turns and `Secs` simulated seconds; `Most knock-offs` is the enemy figure that knocked off the most of your figures (credited to the last flicker), with its count over all fights.

| Type | Act | Target | Fights | Win rate | Turns | Secs | Most knock-offs | Blasters | Bruisers | Control | Skirmishers | Tricksters |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| regular | 1 | Bent Lane | 50 | 76% | 7.0 | 35 | Grunt (67) | 100% | 100% | 30% | 70% | 80% |
| regular | 1 | Bodyguards | 50 | 56% | 16.5 | 89 | Duwall (84) | 80% | 80% | 10% | 20% | 90% |
| regular | 1 | Glass Cannons | 50 | 94% | 5.5 | 28 | Grunt (59) | 100% | 100% | 100% | 70% | 100% |
| regular | 1 | Pushover | 50 | 74% | 8.5 | 46 | Grunt (83) | 90% | 80% | 40% | 70% | 90% |
| regular | 1 | Well-Rounded Squad | 50 | 56% | 11.1 | 57 | Duwall (74) | 60% | 70% | 50% | 20% | 80% |
| regular | 2 | Fireworks | 50 | 86% | 7.1 | 40 | (own side) (43) | 90% | 100% | 80% | 60% | 100% |
| regular | 2 | Ghost Patrol | 50 | 56% | 9.4 | 50 | Ghost (87) | 50% | 80% | 80% | 40% | 30% |
| regular | 2 | Sticky Situation | 50 | 88% | 13.3 | 56 | (own side) (31) | 100% | 90% | 90% | 70% | 90% |
| regular | 2 | The Setup | 50 | 92% | 7.8 | 40 | Grunt (49) | 100% | 100% | 90% | 70% | 100% |
| regular | 2 | Tinderbox | 50 | 78% | 8.5 | 47 | (own side) (42) | 90% | 100% | 40% | 70% | 90% |
| regular | 3 | Demolition Crew | 50 | 82% | 7.6 | 37 | Pusher (65) | 100% | 90% | 80% | 40% | 100% |
| regular | 3 | Fortress | 50 | 64% | 17.6 | 99 | Duwall (51) | 70% | 60% | 50% | 40% | 100% |
| regular | 3 | Speed Trap | 50 | 84% | 7.8 | 54 | Pinhead (66) | 100% | 80% | 80% | 80% | 80% |
| elite | 1 | Big Brother | 50 | 64% | 17.7 | 86 | Duwall (82) | 80% | 90% | 50% | 10% | 90% |
| elite | 1 | Bumper Duo | 50 | 58% | 17.3 | 74 | Bumper (112) | 80% | 70% | 50% | 40% | 50% |
| elite | 1 | Pinball Wizard | 50 | 92% | 8.1 | 49 | Speedo (52) | 90% | 100% | 80% | 90% | 100% |
| elite | 1 | Shield Wall | 50 | 58% | 43.9 | 127 | Shieldon Ooper (86) | 90% | 30% | 60% | 40% | 70% |
| elite | 2 | Banshee | 50 | 56% | 9.2 | 48 | Ghost (152) | 50% | 100% | 20% | 40% | 70% |
| elite | 2 | Glue Gang | 50 | 86% | 17.5 | 82 | (own side) (38) | 100% | 70% | 100% | 70% | 90% |
| elite | 2 | Juice Bar | 50 | 68% | 9.2 | 52 | Bummer (48) | 90% | 50% | 80% | 40% | 80% |
| elite | 2 | Powder Keg | 50 | 82% | 6.5 | 34 | Bombo (75) | 60% | 90% | 80% | 80% | 100% |
| elite | 2 | Swarm | 50 | 96% | 7.3 | 79 | Swarmling (73) | 100% | 100% | 90% | 100% | 90% |
| elite | 2 | Ultimate Shieldon | 50 | 64% | 16.6 | 84 | Ultimate Shieldon (73) | 50% | 90% | 70% | 20% | 90% |
| elite | 3 | Bloodbath | 50 | 70% | 13.4 | 66 | Bloodluster (74) | 90% | 90% | 50% | 50% | 70% |
| elite | 3 | Mirror Match | 50 | 48% | 20.2 | 72 | (own side) (52) | 50% | 60% | 30% | 30% | 70% |
| elite | 3 | Siege | 50 | 30% | 39.5 | 164 | (own side) (50) | 60% | 20% | 20% | 10% | 40% |
| elite | 3 | The Collector | 50 | 22% | 9.0 | 42 | (own side) (93) | 30% | 20% | 10% | 20% | 30% |
| boss | 1 | Sniper Squad | 50 | 58% | 4.4 | 35 | Sniper (134) | 100% | 0% | 100% | 0% | 90% |
| boss | 1 | The Wall | 50 | 16% | 16.7 | 79 | (own side) (45) | 30% | 10% | 0% | 0% | 40% |
| boss | 2 | Slime | 50 | 56% | 7.5 | 43 | Slime (97) | 10% | 100% | 80% | 0% | 90% |
| boss | 2 | Trangle | 50 | 26% | 5.9 | 45 | Trangle (176) | 30% | 50% | 30% | 10% | 10% |
| boss | 3 | Mad Creator | 50 | 14% | 6.3 | 56 | Powerhouse (50) | 0% | 0% | 70% | 0% | 0% |
| boss | 3 | Skull-o-tron | 50 | 22% | 6.1 | 34 | Skull-o-tron (137) | 0% | 80% | 30% | 0% | 0% |

## Sim 4: full runs, Ascension 0 (200 runs, policy `rarity`)

Win rate **0%** (95% CI 0%-2%). Average act reached 1.01; average nodes played 1.7 (1.5 fights). Events are skipped by the bot.

**Caveat:** the bot won no run, and nearly all die in act 1 (see the bot sanity check above), so the pick, money and shop tables below describe the first few nodes only. Treat them as a smoke test of the pipeline, not as balance data, until the bot wins more fights.


Where runs end (losses only):

| Act | Deaths | Share of all runs |
|---|---|---|
| Act 1 | 198 | 99% |
| Act 2 | 2 | 1% |

| Node type | Deaths | Share of all runs |
|---|---|---|
| COMBAT | 193 | 96% |
| BOSS | 6 | 3% |
| ELITE | 1 | 0% |

| Killed by (encounter / boss) | Deaths |
|---|---|
| Grunts only | 131 |
| Well-Rounded Squad | 18 |
| Bodyguards | 15 |
| Pushover | 12 |
| Glass Cannons | 8 |
| Bent Lane | 8 |
| Sniper Squad | 3 |
| The Wall | 2 |
| Ghost Patrol | 1 |
| Big Brother | 1 |


Most-picked figures (picks, and picks per run in winning / losing runs):

| Figure | Winning runs | Losing runs | Total picks |
|---|---|---|---|
| Alchemist | 0 (0.00 per run) | 6 (0.03 per run) | 6 |
| Duwall | 0 (0.00 per run) | 6 (0.03 per run) | 6 |
| Shieldon Ooper | 0 (0.00 per run) | 6 (0.03 per run) | 6 |
| Ghost | 0 (0.00 per run) | 6 (0.03 per run) | 6 |
| Land Miner | 0 (0.00 per run) | 5 (0.03 per run) | 5 |
| Spitter | 0 (0.00 per run) | 5 (0.03 per run) | 5 |
| Juicer | 0 (0.00 per run) | 5 (0.03 per run) | 5 |
| Pusher | 0 (0.00 per run) | 5 (0.03 per run) | 5 |
| Crazy Man | 0 (0.00 per run) | 4 (0.02 per run) | 4 |
| Energizer | 0 (0.00 per run) | 4 (0.02 per run) | 4 |
| Speedo | 0 (0.00 per run) | 4 (0.02 per run) | 4 |
| Magnet | 0 (0.00 per run) | 4 (0.02 per run) | 4 |
| Rally | 0 (0.00 per run) | 4 (0.02 per run) | 4 |
| Pinhead | 0 (0.00 per run) | 4 (0.02 per run) | 4 |


Most-picked relics (picks, and picks per run in winning / losing runs):

| Relic | Winning runs | Losing runs | Total picks |
|---|---|---|---|
| Safety Net | 0 (0.00 per run) | 7 (0.04 per run) | 7 |
| Starter Walls | 0 (0.00 per run) | 6 (0.03 per run) | 6 |
| Opening Act | 0 (0.00 per run) | 6 (0.03 per run) | 6 |
| Second Wind | 0 (0.00 per run) | 2 (0.01 per run) | 2 |
| Aim Assist | 0 (0.00 per run) | 1 (0.01 per run) | 1 |
| Last One Standing | 0 (0.00 per run) | 1 (0.01 per run) | 1 |
| Costume Change | 0 (0.00 per run) | 1 (0.01 per run) | 1 |


Money per run: earned $0.9, spent $0.2 (23% of it), left over $0.7. Winning runs earned $0.0 and spent $0.0; losing runs earned $0.9 and spent $0.2.


Shop items bought ('offered' = in stock in a shop the bot visited):

| Category | Offered | Bought | Bought share |
|---|---|---|---|
| figure | 27 | 6 | 22% |
| relic | 9 | 1 | 11% |
| finish | 9 | 1 | 11% |
| swap | 9 | 0 | 0% |
| power | 9 | 0 | 0% |
| equipment | 9 | 0 | 0% |
| upgrade | 9 | 0 | 0% |

| Item | Offered | Bought | Bought share |
|---|---|---|---|
| figure: Splitter | 3 | 2 | 67% |
| figure: Wikka Wat | 2 | 2 | 100% |
| finish: Finish: Rubber | 3 | 1 | 33% |
| relic: Relic: Clean Sheet (Uncommon) | 1 | 1 | 100% |
| figure: Spitter | 2 | 1 | 50% |
| figure: Blastoid | 2 | 1 | 50% |
| figure: Energizer | 2 | 0 | 0% |
| figure: Aggro-bom | 3 | 0 | 0% |
| swap: Swap a figure | 9 | 0 | 0% |
| relic: Relic: Grippy Table (Common) | 1 | 0 | 0% |
| power: Power: Glue Puddle | 1 | 0 | 0% |
| equipment: Equipment: Rubber Ring (Common) | 1 | 0 | 0% |
| upgrade: Upgrade | 9 | 0 | 0% |
| finish: Finish: Glow-in-the-dark | 3 | 0 | 0% |
| figure: Glue Guy | 2 | 0 | 0% |

## Sim 4: full runs, Ascension 5 (100 runs, policy `rarity`)

Win rate **0%** (95% CI 0%-4%). Average act reached 1.01; average nodes played 1.9 (1.7 fights). Events are skipped by the bot.

**Caveat:** the bot won no run, and nearly all die in act 1 (see the bot sanity check above), so the pick, money and shop tables below describe the first few nodes only. Treat them as a smoke test of the pipeline, not as balance data, until the bot wins more fights.


Where runs end (losses only):

| Act | Deaths | Share of all runs |
|---|---|---|
| Act 1 | 99 | 99% |
| Act 2 | 1 | 1% |

| Node type | Deaths | Share of all runs |
|---|---|---|
| COMBAT | 95 | 95% |
| BOSS | 4 | 4% |
| ELITE | 1 | 1% |

| Killed by (encounter / boss) | Deaths |
|---|---|
| Grunts only | 58 |
| Glass Cannons | 9 |
| Bodyguards | 9 |
| Pushover | 7 |
| Well-Rounded Squad | 6 |
| Bent Lane | 5 |
| Sniper Squad | 2 |
| The Wall | 2 |
| Bumper Duo | 1 |
| The Setup | 1 |


Most-picked figures (picks, and picks per run in winning / losing runs):

| Figure | Winning runs | Losing runs | Total picks |
|---|---|---|---|
| Energizer | 0 (0.00 per run) | 6 (0.06 per run) | 6 |
| Alchemist | 0 (0.00 per run) | 5 (0.05 per run) | 5 |
| Absorber | 0 (0.00 per run) | 4 (0.04 per run) | 4 |
| Sneaky Bomber | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Crazy Man | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Speedo | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Cha-ching | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Duwall | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Blastoid | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Shieldon Ooper | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Splitter | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Pusher | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Powerhouse | 0 (0.00 per run) | 2 (0.02 per run) | 2 |
| Spitter | 0 (0.00 per run) | 2 (0.02 per run) | 2 |


Most-picked relics (picks, and picks per run in winning / losing runs):

| Relic | Winning runs | Losing runs | Total picks |
|---|---|---|---|
| Opening Act | 0 (0.00 per run) | 6 (0.06 per run) | 6 |
| Last One Standing | 0 (0.00 per run) | 3 (0.03 per run) | 3 |
| Safety Net | 0 (0.00 per run) | 2 (0.02 per run) | 2 |
| Starter Walls | 0 (0.00 per run) | 2 (0.02 per run) | 2 |
| Lucky Coin | 0 (0.00 per run) | 1 (0.01 per run) | 1 |
| Costume Change | 0 (0.00 per run) | 1 (0.01 per run) | 1 |
| Wet Explosions | 0 (0.00 per run) | 1 (0.01 per run) | 1 |
| Out the Gate | 0 (0.00 per run) | 1 (0.01 per run) | 1 |


Money per run: earned $1.3, spent $0.0 (0% of it), left over $1.3. Winning runs earned $0.0 and spent $0.0; losing runs earned $1.3 and spent $0.0.


Shop items bought ('offered' = in stock in a shop the bot visited):

| Category | Offered | Bought | Bought share |
|---|---|---|---|
| figure | 3 | 0 | 0% |
| swap | 1 | 0 | 0% |
| relic | 1 | 0 | 0% |
| power | 1 | 0 | 0% |
| equipment | 1 | 0 | 0% |
| upgrade | 1 | 0 | 0% |
| finish | 1 | 0 | 0% |

| Item | Offered | Bought | Bought share |
|---|---|---|---|
| figure: Ghost | 1 | 0 | 0% |
| figure: Magnet | 1 | 0 | 0% |
| figure: Aggro-bom | 1 | 0 | 0% |
| swap: Swap a figure | 1 | 0 | 0% |
| relic: Relic: Home Field (Common) | 1 | 0 | 0% |
| power: Power: Bomb Drop | 1 | 0 | 0% |
| equipment: Equipment: Coin Purse (Uncommon) | 1 | 0 | 0% |
| upgrade: Upgrade | 1 | 0 | 0% |
| finish: Finish: Rubber | 1 | 0 | 0% |

## How these numbers were made

**Sample sizes.** The committed numbers use a smaller sample than the requested 50 fights per matchup / 200 + 100 runs, to fit this session. Full-size time is extrapolated from the wall-clock of the sample (4 workers on a 4-core machine; `python3 tools/balance/run_sims.py` with no options runs the full set).

| Sim | Sample | Full set | Sample wall-clock | Full set, estimated |
|---|---|---|---|---|
| 1 (403 matchups) | 403 x 6 = 2418 | 403 x 50 = 20150 | 7.2 min | 60 min |
| 2 (496 matchups) | 496 x 4 = 1984 | 496 x 50 = 24800 | 10.3 min | 129 min |
| 3 (165 matchups) | 165 x 10 = 1650 | 165 x 50 = 8250 | 7.5 min | 38 min |
| 4, Ascension 0 | 200 runs | 200 runs | 0.9 min | 1 min |
| 4, Ascension 5 | 100 runs | 100 runs | 0.5 min | 0 min |

**Bot sanity check** (100 runs at Ascension 0 with the default policy, different bot aim accuracy). The first fight of every run is 4 Grunts against 4 Grunts on a random layout, so a strong bot should win clearly more than half of them. It wins about a third, and perfect aim does not change that: either the player side really starts at a disadvantage against this AI (the figures start on the deck strip, within reach of the enemy's first shot) or the bot plays the mirrored evaluation worse than the AI plays it. Absolute win rates in this report are therefore low; compare rows with each other.

| Bot accuracy | First fights | First-fight wins | All fights | All-fight wins | Runs won | Runs | Avg act reached |
|---|---|---|---|---|---|---|---|
| 0.85 | 100 | 34% | 164 | 39% | 0 | 100 | 1.02 |
| 1.0 | 100 | 36% | 160 | 38% | 0 | 100 | 1.0 |

**Speed check** (same 30 Pusher-vs-act-1 fights in each mode, same seeds). Fast mode is only used if it gives the same averages as normal speed; single fights can still differ because the game's timers and the physics steps line up differently, so a fight is not bit-identical across modes.

| Mode | Fights | Win % | Figures lost | Player turns | Sim s | Wall s per fight | Same win/loss | Same turns | Matches normal speed? |
|---|---|---|---|---|---|---|---|---|---|
| realtime (normal speed) | 30 | 40 | 3.57 | 7.7 | 42.4 | 42.49 | 30/30 | 30/30 | reference |
| fixed (--fixed-fps 60) | 30 | 43 | 3.43 | 7.8 | 43.1 | 0.58 | 19/30 | 6/30 | yes (same averages; single fights diverge) |
| x8 (Engine.time_scale 8; cut off after 22 of 30 fights) | 22 | 41 | 3.59 | 14.3 | 12.8 | 12.79 | 10/22 | 1/22 | NO (turns 14 vs 8, fights 13 s vs 42 s: settling and timers run on scaled time) |

| Sim | Rows | Wall-clock | Notes |
|---|---|---|---|
| 1 | 2418 | 430 s | 4 workers, mode fixed, fights per matchup 6 |
| 2 | 1984 | 620 s | 4 workers, mode fixed, fights per matchup 4 |
| 3 | 1650 | 450 s | 4 workers, mode fixed, fights per matchup 10 |
| 4_a0 | 200 | 55 s | 4 workers, mode fixed |
| 4_a5 | 100 | 30 s | 4 workers, mode fixed |

Bot and limits (read before trusting a number):
- The bot is the enemy AI's shot evaluation mirrored for the player (elite depth, aim error from accuracy 0.85). It is a decent but not perfect player; absolute win rates say more about the bot than about a human. Compare rows with each other.
- Powers: it uses Extra Turn, Super Flick, Bomb Drop, Freeze Ray, Shrink Ray and Rewind; other powers are held unused. Events (the Trader and the four minigames) are skipped in full runs; chests, shops, elites and bosses are played.
- Sim 1 and 2 decks are one figure plus three Grunts, so they measure a figure's contribution to a weak deck, not its best use.
- The AI's search normally stops after 700 real milliseconds; the sims remove that cut-off so a result does not depend on how fast the machine is.
- Re-run with `python3 tools/balance/run_sims.py` (options at the top of that file); CSVs with every fight are next to this file.
