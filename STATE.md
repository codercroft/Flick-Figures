# STATE.md: what the game actually does (as of 2026-11-04)

Snapshot of the CODE, not of old prompts. Numbers come from the .tres resources and script defaults. If something here disagrees with CLAUDE.md or a prompt, this file (checked against the code) wins. Update it after every task (see CLAUDE.md).

Godot 4.3, GDScript, GL Compatibility renderer, portrait 1080 wide (height varies), one-thumb controls.

---

## 1. Core rules

### Board and table
- Board rect 900 x 1000 at (90, 360); deck strip 900 x 300 directly below (y 1360-1660). The "table" is both. Any figure (either team, on deck or not) whose **centre** leaves the table is knocked off (fades over 0.4 s).
- Collision layers: 1 on-deck, 2 flicked, 3 enemy, 4 arena (walls/pins; everything collides with it). Player flicks pass through the player's own on-deck figures; enemies hit them. Flicked player figures: layer 2, mask 2+3. Enemies: layer 3, mask 1+2+3. Continuous collision detection is CAST_SHAPE.
- No gravity. Slowing is linear damping only: base `figure_damping` 1.5 x the figure's damping multiplier x equipment/relic multipliers.

### Flick controls
- Tap one of your figures to select it (yellow ring), then press and drag ANYWHERE: the flick goes opposite the drag, in any direction. Pressing directly on a figure selects and aims in one motion.
- Drag shorter than 40 px counts as a tap (tap on empty board = placement/shot for Pinhead, Engineer, Alchemist, Blastoid). Full power at a drag of 30% of the viewport width (324 px).
- Impulse = 2400 x (drag / full-drag) x the figure's flick power x modifiers; launch speed = impulse / mass. Modifiers: Super Flick x3 (consumed by the next flick), Opening Act x2 (first flick of a combat), Underdog x1.5, Last One Standing x2, Crazy Man aura x1.5, Jet Pack bonus flick x0.5, enemy-side relics for enemies.
- The aim line is drawn from the selected figure (Aim Assist adds the first bounce).

### Cycle rules
- A flicked figure is greyed out and cannot be flicked again until every other figure has been flicked ("cycle"); then ALL remaining figures become flickable again where they stand. There is no reload step (`Main.reload_enabled`, off, would bring back tap-to-reload).
- Placements (Pinhead pin, Alchemist zone, Engineer turret): at most one per figure per turn. Pinhead and Engineer can place AND flick; Alchemist placing uses up its action (place OR flick). Blastoid: a drag (flick) OR a tap (shot), not both.
- Extra flicks (one shared system: `Main._offer_bonus_flick`, which re-enables `flickable`; label "Bonus flick! <Figure> can flick again (drag, or Skip to end turn)" plus a Skip button; tested by `tools/bonus_flick_test.gd`): Speedo 2/turn (3 with Triple Dash), Jet Pack one half-power flick per combat, Bloodluster a bonus flick after a flick that knocked something off (unlimited chain, each with +35% damping stack), Extra Turn power.

### Turn structure
1. Player flicks ONE figure (powers can be used any time on the player's turn without ending it).
2. Everything settles (see below).
3. Enemy side takes N flicks (N = max(encounter value, DifficultyConfig value 1); bosses use their own value). Each flick: the AI scores the best shot of every candidate enemy and takes the single best (real attacks > repositioning > passing). With `no_repeat_enemy` (on) the enemy that flicked last is not a candidate unless it is alone. Between flicks the board settles. Creepers (The Wall) all creep together after the enemy turn.
4. Back to the player. Start-of-turn: round effects tick, placements unlock, and if no figure is flickable the squad re-arms.

### Settle logic
- A figure is "slow" under 15 px/s; after 5 slow frames in a row it "rests" (velocity zeroed). Continuous-push abilities skip slow figures. The turn waits until everything rests and no projectile is flying (0.3 s settle delay). After 6 s everything is force-stopped; after 5 s an orange debug readout shows what is still moving. A 90 s watchdog hands control back if a turn ever hangs.

### Win / loss
- Win: every enemy is off the table. Mad Creator: the Creator off the table wins (summons vanish). Slime/Skull-o-tron: all pieces/balls off.
- Loss: all player figures off, or (The Wall) any wall piece's front edge reaches the deck line.
- On a combat win: money = $1 per own figure still on the table that "pays income" (Splitter minis do not) + each figure's `income_bonus` (Cha-ching 2, 3 upgraded) + Coin Purse +$1 + Lucky Coin +$1 + node bonus (elite +$2, boss +$5).

---

## 2. Run structure

### Acts and map
- 3 acts. Each act has its own map from seed `hash([run_seed, act])`: 6 columns x 4 lanes (a lane may be missing in a column, 50% chance, at most one) plus a boss node. Verified over 500 generated maps: 20-25 nodes per map (avg 22.5).
- Each node links to 2-3 nodes of the next column; the last column links to the boss. Column 0 is all Combat.
- Column 2 (the 3rd row) is the **chest row**: every node there is a Treasure node, so every path passes exactly one chest (3-4 chests exist per map).
- Shops: 1-3 per act (weights 1:2:1, avg 2.0), at most one per row, never in the chest row. Events: 1-3 per act (avg 2.0), same rules, placed on plain combat nodes. NOTE: the config says "from column 2", but column 2 is the chest row, so in practice the first shop/event can appear in column 3 (the 4th row).
- Elites: at least one per act (avg 1.55, max seen 5), only from column 3, chosen at 25% per eligible node, always avoidable.
- The first combat of a run is always plain Grunts (4, or 5 at Ascension 10) on a random arena. Later combats use hand-made encounters (never repeating until all are used).
- Node flow: Combat/Elite/Boss -> combat scene -> reward screens -> map. Shop -> shop scene. Treasure -> reward scene. Event -> event scene. Run ends on loss or after the last boss (Ascension 11: after the second act 3 boss).

### Combat lineups
- Regular combat: hand-made encounter (section 6) topped up with Grunts or trimmed to the combat's enemy count: **4 at Ascension 0-2** (every act), 4/5/6 by act from Ascension 3, +1 at Ascension 10. Trimming removes entries from the END of the lineup (Fireworks, Fortress and Demolition Crew have 5 figures, so they lose their last entry below Ascension 3).
- Elite: random named elite available in the act (section 6). Boss: that act's boss (section 7). Boss fights always use Open Field.

### Rewards per node (all chances in `reward_config.tres`)
| Node | Rewards |
|---|---|
| Regular combat | Money (above). Figure draft: pick 1 of 3 figures in every act, rarity rolled per slot by act: act 1 75/24/1, act 2 60/32/8, act 3 50/38/12 (Common/Uncommon/Rare %; the shop's figure rolls use the same weights). If you pick a figure you already own you choose Recruit (add it as usual, pick which figure it replaces) or Upgrade (an Upgrade step on your existing copy instead; disabled if that copy has no tiers left; with several copies you pick which). Offered figures you own show an "Owned" badge. Bonus items after the draft: 0 / 1 / 2 by act, each a random power or equipment item (never an Upgrade). Chance drops: 15% power, 10% equipment. Every step has a skip. |
| Elite | Money +$2. 1 guaranteed random relic (act 3: pick 1 of 3 relics). Figure draft as above (3 choices) but rarity 60/35/5 in every act. Bonus items as above. 1 Upgrade step (pick a figure, then the next tier of one of its paths). Chance drops: 40% power, 30% equipment, 20% finish. |
| Boss | Money +$5. Pick 1 of 3 relics (Boss and Rare relics first, then others). One finish (for a figure you choose) AND 1 Upgrade step. Pick 1 of 3 figures (Rare only, ones you do not own; falls back down in rarity). One guaranteed power (50%) or equipment (50%). |
| Treasure chest | A relic (rarity weights 65/30/5 Common/Uncommon/Rare; never Boss). The act 1 chest always gives a Rare relic. Equipment only if every relic is held. |
| Fight made harder by a lost minigame | +$5 and one extra item step (power/equipment/finish) before the normal rewards. |
- Trophy Case relic: +1 figure choice. Ascension 7: figure choices capped at 2 (also the boss pick) and all chance drops x0.5.
- Power slots: 3. A power drop with full slots lets you replace a held power or discard the new one.

### Shop (fresh stock each visit, from `shop_config.tres`)
| Offer | Count | Price |
|---|---|---|
| Figures (rarity rolled by act like a draft) | 3 | Common $3, Uncommon $5, Rare $8 (replaces a figure you pick) |
| Swap a figure for a random new draftable one | 1 | $3 |
| Relic (never Boss) | 1 | Common $10, Uncommon $12, Rare $14 |
| Power (needs a free slot) | 1 | $4 |
| Equipment | 1 | $5 |
| The Upgrade: pick any figure with a tier left, then a box of its tree (next tier on its path; greyed out when none can): $20 flat (before Ascension markups and Discount upgrades) | 1 | flat |
| Finish (you pick the figure) | 1 | $7 |
Ascension 4: every price x1.5, rounded up.

### Economy
- Start $0. Income: see "On a combat win". Spending: shop, Trader. Cha-ching also pays $1 per enemy knocked off while it is on the table. Piggy Bank scales with held money.

---

## 3. Figures
Stats come from the .tres files: mass, radius (px), flick power (multiplier on 2400), damping multiplier, bounce, knockback-taken multiplier (data value; abilities add more, listed below). Every figure works on either side (white ring = player, red = enemy). "Explosive" = registry tag: Bombo's Shrapnel sets it off. "Economy" = enemies never get it.

### Draftable figures
| Rarity | Figure | Mass | Radius | Flick power | Damping x | Bounce | KB taken x | Upgrade paths | Tags |
|---|---|---|---|---|---|---|---|---|---|
| Common | Aggro-bom | 1 | 56 | 1 | 1 | 0.7 | 1 | Fuse / Rage | explosive |
| Common | Blastoid | 1 | 56 | 1 | 1 | 0.7 | 1 | Artillery / Nuke | explosive |
| Common | Cha-ching | 1 | 55 | 1 | 1 | 0.7 | 1 | Savings / Bounty | economy |
| Common | Crazy Man | 1 | 55 | 1 | 1 | 1 | 1 | Frenzy / Hype | - |
| Uncommon | Land Miner | 1 | 55 | 1 | 1 | 0.7 | 1 | Multi-Mine / Smart Bombs | - |
| Common | Glue Guy | 1 | 55 | 1 | 1 | 0.5 | 1 | Sticky / Tar | - |
| Common | Spitter | 1 | 55 | 1 | 1 | 0.7 | 1 | Firehose / Sprinkler | - |
| Common | Juicer | 1 | 60 | 1 | 1 | 0.7 | 1 | Slick / Squeeze | - |
| Common | Magnet | 1.2 | 60 | 1 | 1 | 0.7 | 1 | Field / Collapse | - |
| Common | Rally | 1 | 55 | 1 | 1 | 0.7 | 1 | Charge / Formation | - |
| Common | Shieldon Ooper | 1.1 | 62 | 1 | 1 | 0.6 | 1 | Bulwark / Spikes | - |
| Common | Splitter | 1.4 | 60 | 1 | 1 | 0.7 | 1 | Brood / Shrapnel | - |
| Uncommon | Alchemist | 0.9 | 58 | 1 | 1 | 0.7 | 1 | Potency / Brew | - |
| Uncommon | Bummer | 1 | 60 | 1 | 1 | 0.7 | 1 | Gloom / Downer | - |
| Uncommon | Absorber | 2 | 66 | 0.8 | 1.1 | 0.5 | 1 | Gut / Spit | - |
| Uncommon | Cluster | 2.2 (3 x 0.73) | ~97 round the three (circles of 45) | 1 | 1 | 0.7 | 1 | Swarm / Rebound | - |
| Uncommon | Duwall | 2.5 | 70 | 1.5 | 1 | 0.5 | 0.5 | Shell / Ram | - |
| Uncommon | Energizer | 0.9 | 56 | 1 | 1 | 0.7 | 1 | Charge / Shock | - |
| Uncommon | Ghost | 1 | 55 | 1 | 1 | 0.7 | 1 | Haunt / Phase | - |
| Uncommon | Piggy Bank | 1.3 | 62 | 1 | 1 | 0.7 | 1 | Hoard / Spender | economy |
| Uncommon | Pinhead | 1 | 60 | 1 | 1 | 0.7 | 1 | Pin Count / Bumper Pins | - |
| Uncommon | Powerhouse | 1 | 60 | 2 | 1 | 0.7 | 1 | Might / Grit | - |
| Uncommon | Pusher | 1 | 60 | 0.8 | 1.3 | 0.7 | 1 | Drive / Shove | - |
| Uncommon | Sneaky Bomber | 0.9 | 55 | 1 | 1 | 0.7 | 1 | Fuse / Stealth | explosive |
| Uncommon | Speedo | 0.6 | 45 | 0.525 | 1 | 0.7 | 1 | Dash / Zip | - |
| Rare | Bloodluster | 1 | 58 | 1 | 1.667 | 0.7 | 1 | Frenzy / Predator | - |
| Rare | Bombo | 1 | 55 | 1 | 1 | 0.7 | 1 | Boom / Shrapnel | explosive |
| Rare | Bumper | 1.1 | 70 | 0.7 | 1.6 | 1 | 0.75 | Spring / Bulk | - |
| Rare | Eater | 0.9 | 54 | 1 | 1 | 0.6 | 1 | Appetite / Digest | - |
| Rare | Engineer | 1 | 60 | 1 | 1 | 0.7 | 1 | Turret / Tech | - |

Explosion rule: explosions set off by the player's side never push player figures; enemy explosions push everyone (their own side too; there is no team immunity any more). Notes: "Explosive": Bombo, Sneaky Bomber, Blastoid, Aggro-bom (Bombo's Shrapnel sets them off). "Economy": Cha-ching, Piggy Bank. Grunt is the starter-only figure (4 in the starting deck).

### Abilities as implemented
| Figure | Ability |
|---|---|
| Rally | When flicked, sends every other teammate (board and deck) at 440 px/s toward that teammate's own nearest opposing figure (forward if none is left). Rallying Cry: also makes those teammates flickable again. |
| Splitter | First impact (>=150 px/s) after a flick splits it into 2 Minis (radius 45, mass 0.78, flick power x0.7, 25% less knockback dealt, no income) that burst out at 260 px/s, +-55 deg, keeping 20% of its speed. Minis are fresh unflicked figures. Triple Split: 3 minis. |
| Cha-ching | Economy only (see Win rules); +$1 per enemy knocked off while it is on the table. |
| Aggro-bom | Counts collisions (pair cooldown 0.2 s); on the 4th it explodes (radius 320, force 1500) and survives; count persists across turns. Hair Trigger: 3. Pips drawn above it. |
| Blastoid | Drag = normal flick. Quick tap on the board = fires a projectile (1200 px/s, no range limit) that explodes (radius 170, force 1200) on a figure, wall or pin, or at the tapped point; Blastoid stays put. Either uses its action. When a set-off (Bombo's Shrapnel upgrade) detonates it, it fires a rocket at the nearest opposing figure on the table instead of exploding where it stands (it stays put and keeps its action). Twin Rockets: 2 rockets per shot (a tap fans them +-6 degrees around the tapped point; a detonation sends one at each of the 2 nearest opposing figures, both at the same one if only one is left). |
| Crazy Man | Bounce 1; after each bump speed x1.3 (cap 3000). Aura radius 300: teammates flick x1.5 and take knockback /1.5. |
| Land Miner | Average stats. Whenever it MOVES faster than 60 px/s (its own flick, a hit, a shove, Rally's nudge, an explosion; either side's turn) it adds the distance to a counter and drops a landmine every 400 px of total travel (the first after 400 px; the counter keeps running between movements; a full-power flick travels about 1590 px = 4 mines). Max 12 live mines per Land Miner (oldest removed first); no mine outside the table or within 40 px of another mine. A mine is a small team-colored marker (ring = player white / enemy red, faint trigger circle) that blocks and collides with nothing and stays for the combat. An OPPOSING figure whose center comes within 70 px sets it off: blast radius 180, force 1800 (x1.3 explosion multiplier; between Bombo 200 / 900 and Sneaky Bomber), then it is gone. Mine blasts follow the friendly-explosion rule (player mines never push player figures; enemy mines push everyone, their own side included), count for Blast Cap and Glow-in-the-dark, and explosions never set mines off. AI: paths through player mines cost 120 per mine, shoving a player figure across its own mines earns 110, a Land Miner's moves earn 30 per player flick lane near each mine they would drop (and it considers 1-3 spacings long mine-laying flicks when it has nothing better). |
| Glue Guy | A collision glues it to that figure (rigid joint) until that figure falls or an explosion hits. Goo Chain: several figures, stuck figures turn sticky, chain cap 5. |
| Juicer | Drops trail pieces (every 80 px while faster than 150 px/s, radius 55, max 30, fade after 3 rounds) pushing MOVING OPPOSING figures the way Juicer was moving when it laid each piece (150 px/s^2, cap 1800). Hitting an opposing figure (>=150 px/s) adds 6 pieces in a ring (75 px) pushing outward. Any opposing figure touching a piece (moving or not) is lightly Doused: +20% knockback taken for 2 rounds, refreshed on contact, not stacking; an Alchemist's +50% Douse wins if the figure has both (lighter green tint for the juice). |
| Magnet | While on the board bends the path of moving OPPOSING figures within 500 px (none inside 150 px; up to 1600 px/s^2 at the edge). Implodes when knocked off (radius 300, strength 1800, 0.4 s; 440 / 2700 if wearing Short Fuse). Big Magnet: radius 700, 2300. |
| Shieldon Ooper | When it stops after its own flick it props up a 190 x 26 wall 10 px in front of it facing the nearest opponent. One wall per Shieldon; it vanishes if Shieldon moves >6 px or is flicked/knocked off. |
| Alchemist | Tap empty board: debuff zone radius 150 (placing uses its action). Opposing figures inside take x1.5 knockback. Touching/passing through Douses an opposing figure for 2 rounds (keeps the x1.5). One zone per Alchemist. |
| Bummer | Aura radius 180: an opposing figure whose body touches it loses control when its side tries to flick it: it auto-flicks with an AI "takeover" shot aimed to hurt itself/its friends (0.9 s delay). Boss bodies never aim themselves off the table: a taken-over boss body flicks at 25% of normal power (`takeover_boss_power_cap`) and only with shots whose predicted stopping point is at least 1.5 x its radius + 150 px from every table edge; if none is safe it passes and the flick is wasted. |
| Duwall | Radius 70, mass 2.5, flick x1.5, takes half knockback. A shell absorbs impact damage (8000 = about 3 big hits); at the threshold it bursts and becomes a Grunt for the combat. Bomb Shelter: immune to explosion knockback. |
| Energizer | The first allied figure it hits during its flick becomes flickable again (enemy: removed from the cycle). |
| Ghost | During its own side's turn it wraps to the opposite edge whenever it leaves the table, keeping velocity (no limit). On the other side's turn it falls normally. Full Haunt: also wraps once per opponent turn. |
| Piggy Bank | Mass and size scale with money: 1x at $0, 2x at $20, 3.5x at $50, soft cap 4x; also deals proportionally more knockback. |
| Pinhead | Tap empty board: place ONE temporary pin (radius 28, kicks figures x1.3) and still flick. Pin lasts until its side's cycle resets; tap it again elsewhere to move, on it to remove (before the once-per-turn lock). |
| Powerhouse | Flick x2; takes x2 knockback from enemy figures. Mega Power: x2.5. |
| Pusher | Flick x0.8, damping x1.3 (short range). During its own flick it hits as if 1.75x heavier, never rebounds, and keeps pushing (2600 px/s^2) for up to 1 s (2 s with Long Haul) while touching its target. |
| Sneaky Bomber | If its flick touches no figure it explodes where it stops (radius 270, force 2200, pushes everyone). Long Fuse: radius grows with distance (45 per 100 px). |
| Speedo | Mass 0.6, flick x0.525; two flicks per turn (offered after the first settles; tap to skip). Triple Dash: three. |
| Bloodluster | Damping x1.667 (flicks about 60% as far). A flick that knocks an opposing figure off earns a bonus flick from where it stopped, chaining while each flick kills; each bonus adds +35% damping until the round ticks or it becomes flickable again (red pips + tint). |
| Bombo | Explodes (radius 200, force 900) on its first hit after each flick and survives. Boom Boom: every hit. |
| Bumper | Bounce 1, damping x1.6, flick x0.7, takes x0.75 knockback. Anything that bounces off it leaves 1.3x faster (not a pushing Pusher). |
| Cluster | Starts as 3 clustlings in ONE rigid body: one circle collision shape of radius 45 per clustling (a tight triangle for 3, a diamond for 4), each drawn as its own small figure, mass 0.73 each (rotation locked). Tap the board instead of flicking: tosses the clustling nearest that direction at 950 px/s (its circle leaves the body, which re-centres); it becomes its own flickable figure (Clustling: radius 45, mass 0.75, flick x0.7, pays no income) and the cluster shrinks and loses mass. Toss OR flick per turn; cannot toss the last one. A loose clustling that touches its own cluster (after 0.4 s) rejoins it in the nearest free spot (the cluster grows back; a full cluster takes none). Big Bunch: starts with 4. |
| Spitter | Select it, then press and hold ~0.25 s without moving (more than 40 px of movement is a normal flick drag) to spray toward the finger; the stream follows it; release stops it. Spraying does not use its action: spray first, then flick (or skip, or spray again, or pick another figure). 20 drops/s, 800 px/s, range 450, each drop pushes 20 impulse (a 3 s spray slides a resting mass-1 figure about 280 px; it nudges and redirects, no more). 4 s of water per combat, shrinking size and mass in proportion down to 50% at empty; a blue arc shows the water. Big Gulp: radius 68, mass 1.6, 6 s of water. |
| Absorber | Its OWN flick hitting an opposing figure with a smaller radius at 300 px/s or more absorbs it (one at a time): the figure leaves play at once (win/loss ignore it), is drawn shrinking inside, and shrinks for 3 rounds (counted at each round tick); then it counts as knocked off. A hit on the Absorber by a teammate of the held figure at 500 px/s or more frees it at its reduced size; if the Absorber falls off, the held figure pops out where it fell. Bosses, boss pieces and uneatable figures cannot be absorbed. Big Belly: radius 80, mass 3 (can absorb Duwall and Bumper, radius 70). |
| Eater | Eats any figure of either team it touches with a smaller radius (not uneatable bosses/pieces): victim counts as knocked off; Eater grows (60% of victim's area, 70% of its mass; caps radius 110, mass 4). |
| Engineer | Tap empty board: place ONE turret (radius 30, mass 0.35, not a Figure). It fires a 260-impulse pellet every 1.5 s at the nearest opposing board figure within 520 px, on BOTH sides' turns, only while figures are moving. |

### Enemy-only and boss figures (not draftable)
| Figure | Mass | Radius | Flick power | Damping x | Bounce | KB taken x | Accuracy | Tags |
|---|---|---|---|---|---|---|---|---|
| Grunt | 1 | 60 | 1 | 1 | 0.7 | 1 | 0.8 | - |
| Mad Creator | 3 | 60 | 1 | 1 | 0.9 | 1 | 0.8 | uneatable, boss body |
| Medium Slime | 2.4 | 70 | 1.3 | 1 | 0.6 | 1.1 | 0.75 | uneatable |
| Mini | 0.78 | 45 | 0.7 | 1 | 0.7 | 1 | 0.8 | no income |
| Skull Ball | 0.7 | 38 | 1 | 1 | 0.7 | 1 | 0.8 | uneatable |
| Skull-o-tron | 14 | 95 | 4 | 1.2 | 0.5 | 1 | 0.7 | uneatable, boss body |
| Slime | 5 | 100 | 2 | 1 | 0.6 | 1 | 0.7 | uneatable, boss body |
| Small Slime | 0.9 | 45 | 1 | 1 | 0.6 | 1.25 | 0.8 | uneatable |
| Sniper | 0.4 | 40 | 1.5 | 1 | 0.7 | 1 | 0.98 | uneatable |
| Swarmling | 0.35 | 30 | 0.6 | 1 | 0.7 | 1.2 | 0.6 | - |
| Trangle | 8 | 120 | 2.8 | 1 | 0.5 | 1 | 0.75 | uneatable, boss body |
| Wall Piece | 6 | 88 | 1 | 1.5 | 0.6 | 1 | 0.8 | uneatable, boss body |

### Upgrade trees
Every draftable figure (not the Grunt) has an `UpgradeTree` (`resources/upgrades/<figure>/tree.tres`, listed in `RunConfig.upgrade_trees`): two paths of three tiers (`a1`..`a3`, `b1`..`b3`; each tier is an `UpgradeData` with a name, a description, stat overrides / multipliers and an optional effect script). Rules: tiers are taken in order; the figure's FIRST upgrade picks its path and locks the other (at most 3 upgrades per figure); upgrades belong to the figure and are lost if it is replaced; finishes are a separate slot. Tier effects are cumulative (tier 2 on top of tier 1...; multipliers compound). The Upgrade reward step shows both paths until the first pick, then only the chosen path (owned / available / locked boxes, tap for the description). Sources: elites 1 Upgrade step, bosses 1 Upgrade step (plus 1 finish), the shop's one Upgrade ($20), duplicate figures (Recruit / Upgrade); regular combats never give one, the Trader's high trade grants one for the new figure. Enemies: from Ascension 5 (Upgraded Enemies) they roll tier 1 on one path, elites and bosses' figures up to tier 2; Mirror Match copies your tiers exactly. Upgrade pips (one per tier owned) show on figures and on the deck strip; the Inventory figure details and the Compendium figure page show the tree. Saved runs migrate the old single upgrades to tiers (Hair Trigger = Fuse 1, Twin Rockets = Artillery 2, Boom Boom = Boom 2, Bomb Shelter = Shell 2, Full Haunt = Haunt 3, Rallying Cry = Charge 3, Long Fuse = Fuse 2, ... lower tiers of the path are filled in).

| Figure | Path | Tier | Name | Effect |
|---|---|---|---|---|
| Aggro-bom | Fuse | 1 | Hair Trigger | Explodes every 3 hits. |
| Aggro-bom | Fuse | 2 | Overcharge | Explosion power +25%. |
| Aggro-bom | Fuse | 3 | Two-Hit Fuse | Explodes every 2 hits. |
| Aggro-bom | Rage | 1 | Hit Fury | +10% knockback for each hit counted. |
| Aggro-bom | Rage | 2 | Hit Bulk | +10% mass and flick power for each hit counted. |
| Aggro-bom | Rage | 3 | Big Bang | Takes 5 hits to explode; the explosion has +50% power. |
| Blastoid | Artillery | 1 | Big Rockets | Rocket radius +25%. |
| Blastoid | Artillery | 2 | Twin Rockets | 2 rockets per shot. |
| Blastoid | Artillery | 3 | Rocket Ring | Firing a rocket fires rockets all around him. |
| Blastoid | Nuke | 1 | Hot Warheads | Rocket power +25%. |
| Blastoid | Nuke | 2 | Dense Warheads | Rocket radius -50%, rocket power +50%. |
| Blastoid | Nuke | 3 | Quake Warheads | Rocket power +50%, radius -20%. A rocket that hits an opponent slams it along the rocket's direction (2.5x the rocket's normal knockback on a touching figure, `direct_hit_multiplier`) on top of the normal small blast, then every OTHER enemy gets the Earthquake shove. |
| Cha-ching | Savings | 1 | Big Spender | +$5 survival bonus. |
| Cha-ching | Savings | 2 | Extra Option | After surviving a combat, gain an extra option when choosing a figure. |
| Cha-ching | Savings | 3 | Discount Card | Shop prices -15% while it is in your deck. |
| Cha-ching | Bounty | 1 | Kill Bounty | Its own kills pay +$3. |
| Cha-ching | Bounty | 2 | Bounty Hunter | +$2 per enemy knocked off while it is on the table. |
| Cha-ching | Bounty | 3 | Big Bounty | +$3 per enemy knocked off while it is on the table. |
| Crazy Man | Frenzy | 1 | Wide Aura | Aura radius +30%. |
| Crazy Man | Frenzy | 2 | Rattled Foes | Opponents in the aura take +25% knockback. |
| Crazy Man | Frenzy | 3 | Aura of Dread | Opponents in the aura have -50% flick power. |
| Crazy Man | Hype | 1 | Wider Aura | Aura radius +30%. |
| Crazy Man | Hype | 2 | Pep Talk | Teammates in the aura gain +25% flick power. |
| Crazy Man | Hype | 3 | Thick Skin | Teammates in the aura gain +30% knockback resistance. |
| Glue Guy | Sticky | 1 | Goo Chain | Chains of up to 5. |
| Glue Guy | Sticky | 2 | Sticky Flicks | +1 flick for every figure he is stuck to. |
| Glue Guy | Sticky | 3 | Thin Prey | Opponents stuck to him lose 50% mass while stuck. |
| Glue Guy | Tar | 1 | Tar Drag | An enemy stuck to it flicks 30% weaker. |
| Glue Guy | Tar | 2 | Locked Down | An enemy stuck to it can't flick. |
| Glue Guy | Tar | 3 | Heavy Tar | +100% mass and +100% flick power while stuck. |
| Juicer | Slick | 1 | Long Trail | Trail lasts 5 rounds. |
| Juicer | Slick | 2 | Strong Push | Trail push +50%. |
| Juicer | Slick | 3 | Edge Steering | The trail always steers toward the edge. |
| Juicer | Squeeze | 1 | Stickier Juice | Juice Douse +30% (from +20%). |
| Juicer | Squeeze | 2 | Big Splash | The splash radius is 50% bigger. |
| Juicer | Squeeze | 3 | Sticky Max | Juice Douse +50% (from +30%). |
| Land Miner | Multi-Mine | 1 | More Mines | Drops mines more often: about 6 per full flick (spacing 400 x0.67 = 268). |
| Land Miner | Multi-Mine | 2 | Bigger Bangs | Mine blast force +40%. |
| Land Miner | Multi-Mine | 3 | Minefield | Drops mines even more often: about 8 per full flick (spacing x0.5 overall = 200). |
| Land Miner | Smart Bombs | 1 | Bigger Mines | Mine radius and force +30%. |
| Land Miner | Smart Bombs | 2 | Tighter Pattern | Mines drop a bit more often (x0.8 = 320 px); radius and force +15% more. |
| Land Miner | Smart Bombs | 3 | Homing Mines | Mines drift toward moving opponents within about 250 px (a gentle pull); they stay put otherwise. |
| Magnet | Field | 1 | Big Magnet | Bigger, stronger pull. |
| Magnet | Field | 2 | Repel Pulse | Once per combat, after flicking, tap it to briefly reverse the pull and push opponents away. |
| Magnet | Field | 3 | Repel Pulses | The push can be used once per turn. |
| Magnet | Collapse | 1 | Big Implosion | Implosion radius +30%. |
| Magnet | Collapse | 2 | Collapse Now | Once per combat, tap to implode on command (uses its action; it stays). |
| Magnet | Collapse | 3 | Black Hole | After it dies it leaves a pull that never affects friendly figures. |
| Rally | Charge | 1 | Quick Nudge | Nudge speed +40%. |
| Rally | Charge | 2 | Hard Hitters | Nudged teammates deal +20% knockback that turn. |
| Rally | Charge | 3 | Rallying Cry | Also makes your team flickable again (resets the flick cycle). |
| Rally | Formation | 1 | Edge Guard | Teammates near an edge are nudged inward instead. |
| Rally | Formation | 2 | Padded Ranks | Nudged teammates take 25% less knockback until your next turn. |
| Rally | Formation | 3 | Rally Hits | Its hits also trigger the rally. |
| Shieldon Ooper | Bulwark | 1 | Wide Wall | Wall 50% wider. |
| Shieldon Ooper | Bulwark | 2 | Sturdy Wall | The wall survives small nudges (breaks past 40 px). |
| Shieldon Ooper | Bulwark | 3 | Wall Chain | When it sets up a wall, the nearest teammate also sets one up, pointed at its nearest opponent. |
| Shieldon Ooper | Spikes | 1 | Bouncy Wall | Wall bounce +50%. |
| Shieldon Ooper | Spikes | 2 | Bumper Wall | The wall launches figures like a Bumper (x1.3). |
| Shieldon Ooper | Spikes | 3 | Wet Wall | Enemies that hit the wall get Doused. |
| Splitter | Brood | 1 | Triple Split | 3 minis. |
| Splitter | Brood | 2 | Big Minis | Minis 25% bigger. |
| Splitter | Brood | 3 | Re-Split | Minis can split once more. |
| Splitter | Shrapnel | 1 | Fast Burst | Minis burst out 50% faster. |
| Splitter | Shrapnel | 2 | Full Force | Minis deal full knockback. |
| Splitter | Shrapnel | 3 | Splinter Blast | The split makes a small explosion. |
| Spitter | Firehose | 1 | Big Gulp | Bigger and heavier, with more water. |
| Spitter | Firehose | 2 | Pressure | Push per drop +50%. |
| Spitter | Firehose | 3 | Steady Size | Doesn't shrink while spraying. |
| Spitter | Sprinkler | 1 | Wet Spray | The spray lightly Douses (+20%). |
| Spitter | Sprinkler | 2 | Refill | Refills 1 s of water per round. |
| Spitter | Sprinkler | 3 | Soaking Spray | The spray heavily Douses (+50%). |
| Absorber | Gut | 1 | Big Belly | Bigger: can swallow Duwalls and Bumpers. |
| Absorber | Gut | 2 | Quick Digest | Immediately shrinks the absorbed unit by 50%. |
| Absorber | Gut | 3 | Three Stomachs | Can hold 3 figures. |
| Absorber | Spit | 1 | Tight Grip | Escape threshold +50%. |
| Absorber | Spit | 2 | Spit Out | Tap to spit the held figure out at high speed (uses its action). |
| Absorber | Spit | 3 | Spit Bomb | Spat figures explode on impact. |
| Alchemist | Potency | 1 | Strong Brew | Douse +75% (from +50%). |
| Alchemist | Potency | 2 | Wide Zone | Zone radius +40%. |
| Alchemist | Potency | 3 | Weakening Brew | Doused enemies also flick 25% weaker. |
| Alchemist | Brew | 1 | Long Douse | Douse lasts 3 rounds. |
| Alchemist | Brew | 2 | Quick Mix | Can place a zone and flick in the same turn. |
| Alchemist | Brew | 3 | Double Zones | Keeps 2 zones at once. |
| Bummer | Gloom | 1 | Wide Gloom | Aura radius +30%. |
| Bummer | Gloom | 2 | Rough Takeover | Takeover shots deal +25% knockback. |
| Bummer | Gloom | 3 | Lingering Gloom | Taken-over figures stay bummed for one more flick. |
| Bummer | Downer | 1 | Weak Aura | Enemies in its aura flick 20% weaker. |
| Bummer | Downer | 2 | Slowing Aura | The aura slows moving enemies. |
| Bummer | Downer | 3 | Painful Gloom | Enemies in its aura take +25% knockback. |
| Cluster | Swarm | 1 | Big Bunch | Starts with 4 clustlings. |
| Cluster | Swarm | 2 | Hard Hitters | Clustlings deal +25% knockback. |
| Cluster | Swarm | 3 | Full Swarm | 5 clustlings. |
| Cluster | Rebound | 1 | Hard Toss | Toss speed +30%. |
| Cluster | Rebound | 2 | Toss and Flick | Can toss and flick in the same turn. |
| Cluster | Rebound | 3 | Homing Pieces | Loose clustlings slide home at the end of your turn. |
| Duwall | Shell | 1 | Thick Shell | Shell 50% tougher. |
| Duwall | Shell | 2 | Bomb Shelter | Immune to explosions. |
| Duwall | Shell | 3 | Regrowth | The shell regrows 25% per round. |
| Duwall | Ram | 1 | Heavy Ram | Flick power x1.75 (from x1.5). |
| Duwall | Ram | 2 | Shell Smash | +30% knockback dealt while the shell holds. |
| Duwall | Ram | 3 | Shrapnel Shell | The shell bursting explodes outward. |
| Energizer | Charge | 1 | Recharge All | Recharges every ally it hits. |
| Energizer | Charge | 2 | Overcharge | Recharged allies get +25% power on their next flick. |
| Energizer | Charge | 3 | Instant Recharge | Recharged allies can flick immediately. |
| Energizer | Shock | 1 | Static Hit | Enemies it hits have reduced flick power. |
| Energizer | Shock | 2 | Chain Lightning | The shock chains to nearby enemies. |
| Energizer | Shock | 3 | Stun | Enemies it hits can't flick next round. |
| Ghost | Haunt | 1 | Spooky Gains | +10% knockback for the combat each time it wraps. |
| Ghost | Haunt | 2 | Spirit Power | +10% flick power for the combat each time it wraps. |
| Ghost | Haunt | 3 | Full Haunt | Also wraps once per opponent turn. |
| Ghost | Phase | 1 | Ghost Walk | Passes through allies. |
| Ghost | Phase | 2 | Teleport | Tap to teleport to another spot; it can still flick that turn. |
| Ghost | Phase | 3 | Wrap Gift | Allies it passes through can wrap around once on either turn. |
| Piggy Bank | Hoard | 1 | Strong Savings | Scales its flick power along with its mass. |
| Piggy Bank | Hoard | 2 | Bigger Vault | Soft cap 5x (from 4x). |
| Piggy Bank | Hoard | 3 | Interest | Gains +1% knockback for every $ you have. |
| Piggy Bank | Spender | 1 | Strong Wallet | Scales its flick power along with its mass. |
| Piggy Bank | Spender | 2 | Receipts | Counts 50% of the money spent this run as held. |
| Piggy Bank | Spender | 3 | Big Spender | Shops cost -15%, and it counts 75% of the money spent this run. |
| Pinhead | Pin Count | 1 | Fat Pins | Pin radius +50%. |
| Pinhead | Pin Count | 2 | Two Pins | Places 2 pins per turn. |
| Pinhead | Pin Count | 3 | Lasting Pins | Pins last the whole combat (max 4). |
| Pinhead | Bumper Pins | 1 | Springy Pins | Pin kick x1.5 (from x1.3). |
| Pinhead | Bumper Pins | 2 | Wet Pins | Enemies that hit its pins get Doused. |
| Pinhead | Bumper Pins | 3 | Bomb Pins | A pin explodes the first time an enemy hits it. |
| Powerhouse | Might | 1 | Mega Power | Flick power x2.5. |
| Powerhouse | Might | 2 | Giga Power | Flick power x3. |
| Powerhouse | Might | 3 | Heavy First Hit | The first hit of each flick lands as if 2x heavier. |
| Powerhouse | Grit | 1 | Normal Skin | Takes normal knockback. |
| Powerhouse | Grit | 2 | Thick Skin | Takes half knockback. |
| Powerhouse | Grit | 3 | Parachute | Saves itself the first time it would fall off each combat. |
| Pusher | Drive | 1 | Long Haul | Pushes for 2 s. |
| Pusher | Drive | 2 | Longer Haul | Pushes for 3 s. |
| Pusher | Drive | 3 | Endless Push | Pushes for 5 s. |
| Pusher | Shove | 1 | Long Range | Range +30%. |
| Pusher | Shove | 2 | Heavy Shove | Hits as if 2.25x heavier (from 1.75x). |
| Pusher | Shove | 3 | Kick Back | Does a small flick away from the edge after a kill. |
| Sneaky Bomber | Fuse | 1 | Friendly Fuse | Still explodes if it only touched allies. |
| Sneaky Bomber | Fuse | 2 | Long Fuse | The explosion radius grows with distance travelled. |
| Sneaky Bomber | Fuse | 3 | Hot Fuse | Explosion force +40%. |
| Sneaky Bomber | Stealth | 1 | Blur | Enemy shots at it are less accurate. |
| Sneaky Bomber | Stealth | 2 | Ambush | If no enemy hits it during the enemy's turn, it explodes. |
| Sneaky Bomber | Stealth | 3 | Big Stealth Blast | Explosion force and radius +25%. |
| Speedo | Dash | 1 | Triple Dash | 3 flicks per turn. |
| Speedo | Dash | 2 | Building Speed | Each flick in a turn is 15% stronger than the last. |
| Speedo | Dash | 3 | Quad Dash | 4 flicks per turn. |
| Speedo | Zip | 1 | Quick Legs | +25% flick power. |
| Speedo | Zip | 2 | Heavy Legs | +50% mass. |
| Speedo | Zip | 3 | Kill Rush | A knockoff earns an extra flick. |
| Bloodluster | Frenzy | 1 | Light Stacks | Damping stacks +20% per kill (from +35%). |
| Bloodluster | Frenzy | 2 | First Blood | Its first kill each combat recharges an ally. |
| Bloodluster | Frenzy | 3 | Stackless | No damping stacks. |
| Bloodluster | Predator | 1 | Edge Hunter | +25% knockback against Doused or near-edge enemies. |
| Bloodluster | Predator | 2 | Blood Scent | +15% knockback per kill this combat. |
| Bloodluster | Predator | 3 | Pack Hunter | An ally's kill gives it a bonus flick (once per turn). |
| Bombo | Boom | 1 | Wide Blast | Explosion radius +25%. |
| Bombo | Boom | 2 | Boom Boom | Explodes on every hit. |
| Bombo | Boom | 3 | Heavy Charge | Explosion force +40%. |
| Bombo | Shrapnel | 1 | Chain Blast | Its explosion sets off allied explosives. |
| Bombo | Shrapnel | 2 | Boom Boom | Explodes on every hit. |
| Bombo | Shrapnel | 3 | Last Gasp | Also explodes when knocked off. |
| Bumper | Spring | 1 | Springier | Launch x1.5 (from x1.3). |
| Bumper | Spring | 2 | Springiest | Launch x1.8 and increased flick power. |
| Bumper | Spring | 3 | Ultra Spring | Launch x2. |
| Bumper | Bulk | 1 | Heavy Frame | +30% mass. |
| Bumper | Bulk | 2 | Armored | Takes half knockback. |
| Bumper | Bulk | 3 | Easy Rolling | Normal flick power and damping. |
| Eater | Appetite | 1 | Tasty Treats | +$1 per meal. |
| Eater | Appetite | 2 | Bigger Belly | Growth cap radius 140 (from 110). |
| Eater | Appetite | 3 | Equal Eater | Can eat figures its own size. |
| Eater | Digest | 1 | Slow Digest | Keeps 80% of a meal's mass (from 70%). |
| Eater | Digest | 2 | Meal Muscle | +10% knockback dealt per meal. |
| Eater | Digest | 3 | Minion Muncher | Can eat boss minions (medium and small slimes, Skull Balls...). |
| Engineer | Turret | 1 | Rapid Fire | Fires every 1 s (from 1.5 s). |
| Engineer | Turret | 2 | Two Turrets | 2 turrets. |
| Engineer | Turret | 3 | Heavy Turrets | Heavier turrets with stronger pellets. |
| Engineer | Tech | 1 | Wet Pellets | Pellets Douse. |
| Engineer | Tech | 2 | Slowing Pellets | Pellets also slow moving enemies. |
| Engineer | Tech | 3 | Rocket Turret | The turret also fires a small rocket every 4 s. |


---

## 4. Relics, powers, equipment, finishes

### Relics (15)
| Rarity | Relic | Effect (as coded) |
|---|---|---|
| Common | Aim Assist | The aim line shows the first bounce off a wall, pin or figure. |
| Common | Grippy Table | Your figures stop 30% sooner. |
| Common | Costume Change | Equip, unequip and swap equipment in the Inventory during combat, on your own turn (nothing moving, not mid-aim). Costs no flick; effects apply at once. |
| Common | Home Field | Your figures take half knockback in your bottom third of the board. |
| Common | Lucky Coin (economy) | +$1 after every won combat. |
| Uncommon | Blast Cap | Explosions are 50% bigger. |
| Uncommon | Bully | 2x knockback against figures near the table edge. |
| Uncommon | Clean Sheet | Win a combat without losing a figure to gain a random power. |
| Uncommon | Gravity Well | Magnet-type pulls are twice as strong. |
| Uncommon | Trophy Case | Figure rewards offer one more choice. |
| Uncommon | Underdog | +50% flick power while you have fewer figures on the table than the enemy. |
| Rare | Last One Standing | Your final remaining figure gets 2x flick power and takes half knockback. |
| Rare | Opening Act | The first flick of each combat has 2x power. |
| Rare | Starter Walls | Before the enemy's first turn, a wall pops up in front of each unflicked figure on the deck. It lasts that turn. |
| Boss | Extra Pocket | +1 deck slot. |
| Boss | Second Wind | The first of your figures knocked off each combat returns to the deck strip. (Only from boss rewards.) |

Exact numbers: Blast Cap x1.5 radius; Bully x2 within 200 px of the edge; Grippy Table: damping x1/0.7; Home Field x0.5 in the bottom third; Last One Standing x2 power, x0.5 knockback; Opening Act first flick x2; Underdog x1.5 power; Gravity Well x2 pulls (Magnet, Magnet Charm, Magnet Throw); Trophy Case +1 figure choice; Extra Pocket +1 deck slot (Boss rarity, boss reward only); Starter Walls pops a 190 x 26 wall above every unflicked deck figure before the enemy's first turn (lasts that turn); Second Wind returns the first knocked-off figure each combat to its deck slot; Clean Sheet gives a random power if no figure was lost; Aim Assist shows the first bounce.
The enemy-side versions (Ascension 8+/act 3 elites) exist for Blast Cap, Home Field, Underdog, Bully, Grippy Table, Last One Standing, Opening Act (never economy relics).

### Powers (12; 3 slots; used up when used; using one never ends the turn)
| Power | Effect (numbers) |
|---|---|
| Super Flick | Next flick x3 power. |
| Freeze Ray | Tap an enemy: frozen (static, cannot flick) for 1 round. |
| Bubble Shield | Tap your figure: stops at the table edge instead of falling, 1 round. |
| Rewind | Undo your last flick: every figure (knocked-off ones too) returns; restores boost/extra turns/enemy flick count. |
| Swap | Tap two figures: swap positions. |
| Bomb Drop | Tap the board: explosion radius 330, force 2600 (x1.3 global, Blast Cap applies). |
| Earthquake | Every figure gets a random shove 90-280 px/s. |
| Brick | Tap the board: 240 x 44 wall for 2 rounds (refused if a figure is in the way). |
| Extra Turn | Flick once more after the next flick settles, before the enemy acts. |
| Magnet Throw | Tap the board: magnet field radius 225 (inner 90, pull 1400) for 1 round. |
| Glue Puddle | Tap the board: puddle radius 130 stops figures that slide INTO it, rest of the combat. |
| Shrink Ray | Tap an enemy: half size and half mass for the combat. |
Powers can be discarded in the Inventory at any time (including mid-combat).

### Equipment (13; one item per figure; unequipped items sit in storage)
| Rarity | Item | Effect | Flags |
|---|---|---|---|
| Common | Banana Peel | Half damping: slides much farther. | - |
| Common | Mr Potential's Skull | Takes 2x knockback from its own team. Bonk it forward. | player-only (never on enemies) |
| Common | Rubber Ring | +0.5 bounce. | - |
| Common | Weighted Boots | +50% mass: harder to push around. | - |
| Uncommon | Anchor | Ignores light hits (under 500 px/s). | - |
| Uncommon | Coin Purse | +$1 if it is on the table when you win a combat. | economy, player-only (never on enemies) |
| Uncommon | Lucky Charm | Enemy shots aimed at it are less accurate. | player-only (never on enemies) |
| Uncommon | Magnet Charm | A weak pull on nearby moving enemy figures. | - |
| Uncommon | Short Fuse | When knocked off, implodes: pulls nearby figures toward where it left. | - |
| Uncommon | Spiked Helmet | +40% knockback dealt. | - |
| Rare | Jet Pack | One extra half-power flick per combat. | player-only (never on enemies) |
| Rare | Parachute | Once per combat, survives being knocked off by stopping at the edge. | - |
| Rare | Wings | Once per combat, wraps around the table edge like a Ghost. | - |

Numbers: Anchor ignores impacts under 500 px/s; Spiked Helmet +40% knockback dealt; Short Fuse implosion radius 300, strength 1800, 0.4 s; Jet Pack one 0.5-power flick per combat; Lucky Charm +15 deg aim error for enemy shots at it; Mr Potential's Skull takes x2 knockback from its own team; Magnet Charm radius 320, inner 90, pull 380 (no implosion). Equipment is equipped/unequipped in the Inventory (outside combat); replacing a figure returns its item to storage.

### Finishes (5; one per figure; lost when the figure is replaced)
| Finish | Effect |
|---|---|
| Glitter | +25% knockback dealt. |
| Metallic | Mass x1.5, takes 25% less knockback. |
| Glow-in-the-dark | Ability numbers x1.5 (explosion/blast radius, pull radius/acceleration, bounce boost, bump ratio, nudge speed, aura radius). Only offered for figures with such numbers. |
| Translucent | Ignores the first ally it touches each flick (alpha 0.55). |
| Rubber | x1.5 speed after bouncing off a wall or pin. |
Gear rules: gear that would do nothing for a figure is never rolled (e.g. Glow needs scalable numbers, Wings not on Ghost, Magnet Charm not on Magnet); random gear is weighted by figure role (heavy, light, power, bouncy, slider, explosive).

---

## 5. Arenas and floor elements
Positions are board space (900 x 1000, enemies at the top). Floor patches only act on MOVING figures. Arena constants: wall bounce 0.8; pins bounce 1.0 and kick figures x1.3; SLOW patch adds damping 3.0; BOOST patch 470 px/s^2 (cap 2400); TURN patch rotates a moving figure's velocity 110 deg/s (speed kept). "Creeper-safe" arenas are the only ones The Wall can use (it only appears in boss fights, which always use Open Field, so this only matters for the pool).
| Layout | Contents | Creeper-safe |
|---|---|---|
| Open Field | nothing (also every boss fight) | yes |
| Corner Posts | 6 wall segments: an L of two walls (260 x 36 and 36 x 260) in each top corner, and one 36 x 260 wall at each bottom side corner | yes |
| Open Corners | top wall 560 wide + two side walls 640 tall, corners open | yes |
| Side Rails | two full-height side walls | yes |
| Divider | three 40-thick wall segments at y 560 with two gaps (widths 200 / 140 / 200) | no |
| The Funnel | two angled walls (about 29 deg) at y 610 narrowing to the middle | no |
| Pinball | 4 round pins (radius 28) at (200,560) (700,560) (325,780) (575,780) | no |
| Mud Flats | 3 SLOW patches (260x200, 260x200, 180x140) | no |
| Speedway | two side walls (y 640, 720 tall), two BOOST lanes (150 x 420, up) at x 270 and 630 and a short reverse BOOST (200 x 140, down) | no |
| Whirlpool | center pin (radius 36) inside a 320 x 320 TURN patch plus two 220 x 200 TURN patches low on the sides | no |
| Crosswinds | three 440 x 110 BOOST strips at y 450 (right), 620 (left), 790 (right), centred | no |
| Fortress Walls | top wall 460 wide, two side walls 560 tall, two 170 x 36 bunkers at y 600 | no |
Random pool (`RunConfig.arenas`): all but Fortress Walls, never the same twice in a row. Fortress Walls is used only by encounters (Fortress, Siege). Temporary floor things created in play: Juicer trail pieces, Alchemist zones, Pinhead pins, Engineer turrets, Shieldon/Starter walls, Bricks, Magnet-Throw fields, Glue Puddles.

---

## 6. Encounters
Regular combats pick an unplayed encounter available in the act (all used = reset). "+ Grunts" = filled with Grunts in free spots to the combat's enemy count (4 at Ascension 0-2). All have 1 enemy flick per turn.

### Regular (13; the pool starts from the second combat of a run)
| Act | Encounter | Lineup | Arena |
|---|---|---|---|
| 1 | Bodyguards | 2 Duwall, 2 Grunt | Side Rails |
| 1 | Bent Lane | Magnet, 3 Grunt | Open Field |
| 1 | Glass Cannons | 2 Powerhouse, 2 Grunt | Pinball |
| 1 | Pushover | 2 Pusher, 2 Grunt | Corner Posts |
| 1 | Well-Rounded Squad | Powerhouse, Duwall, Magnet (each mass x1.25, power x1.15, accuracy x1.1) + Grunts | random |
| 2 | Tinderbox | Bombo, 2 Land Miner | The Funnel |
| 2 | Ghost Patrol | 3 Ghost, Duwall | Open Field |
| 2 | The Setup | Grunt wearing Mr Potential's Skull, 2 Grunt, Rally | Divider |
| 2 | Sticky Situation | Glue Guy, 2 Splitter | Mud Flats |
| 2 | Fireworks | 2 Land Miner, 2 Speedo, Magnet (5, trimmed to 4 below Ascension 3) | random |
| 3 | Fortress | 2 Duwall, Magnet, 2 Powerhouse (5, trimmed to 4 below Ascension 3) | Fortress Walls |
| 3 | Speed Trap | Juicer, 2 Speedo, Pinhead | Speedway |
| 3 | Demolition Crew | Crazy Man, 2 Pusher, Bombo, Sneaky Bomber (5, trimmed to 4 below Ascension 3) | Pinball |
Every encounter has fixed start positions inside its arena (checked headless: nothing overlaps a wall).

### Elites (13; picked at random among those available in the act)
| Act | Elite | Lineup | Arena | Flicks/turn |
|---|---|---|---|---|
| 1 | Bumper Duo | 2 Bumper (mass x1.5, bounce +0.1, bump ratio x1.4) | random | 1 |
| 1 | Big Brother | Duwall (radius x1.5, mass x1.5, shell 16000) + 2 Grunt | random | 1 |
| 1 | Shield Wall | 3 Shieldon Ooper + Grunt | random | 1 |
| 1 | Pinball Wizard | Crazy Man + 2 Speedo inside his aura | Corner Posts | 1 |
| 2 | Swarm | 8 Swarmling | random | 3 |
| 2 | Banshee | 5 Ghost | Open Field | 1 |
| 2 | Powder Keg | Land Miner, Aggro-bom, 2 Bombo (clustered) (+ Grunts when the count is higher) | random | 1 |
| 2 | Glue Gang | Glue Guy with Goo Chain + 2 Splitter | random | 1 |
| 2 | Juice Bar | Juicer, 2 Speedo, Bummer | random | 1 |
| 3 | Mirror Match | one enemy per combat slot cycling through YOUR deck's figure types (economy ones become Grunts), each with copies of your equipment/finish/upgrade for that slot; mass/power/accuracy x1.1 | random | 1 |
| 3 | The Collector | Eater (size and mass x1.3, feeds on its own Grunts) + 4 Grunt | random | 1 |
| 3 | Siege | Engineer (turret placed before your first flick), 2 Shieldon Ooper, Duwall | Fortress Walls | 1 |
| 3 | Bloodbath | 2 Bloodluster + Alchemist (+ Grunts when the count is higher) | random | 1 |
Elite fights pay +$2 and the elite rewards (section 2). Banner at the start of a fight shows the encounter name (gold), the arena and any enemy relic.

---

## 7. Bosses (all fights on Open Field)
| Act | Boss | Bodies | Flicks per turn | Back wall | Special rules |
|---|---|---|---|---|---|
| 1 | The Wall | 5 Wall Pieces (mass 6, radius 88, damping x1.5) in a straight row | 1 (pieces never flick) | no | After every enemy turn ALL pieces creep 55 px toward the deck together; any front edge reaching the deck line loses. |
| 1 | Sniper Squad | 5 Snipers (mass 0.4, radius 40, flick x1.5, accuracy 0.98) | 2 | no | Fragile, accurate. |
| 2 | Trangle | 1 body, mass 8, radius 120, flick x2.8, concave-triangle collision shape | 2 | yes | Gets 12 rad/s spin on every flick (decays 1.8/s) so its hollows sweep figures. |
| 2 | Slime | Large (r100, m5, flick x2) | 1 per slime piece on the table (cap 4) | yes | Splits (impact >=350 px/s) into 2 medium (r70, m2.4; split >=300), each into 2 small (r45, m0.9, never split). New pieces ignore hits 0.5 s and take half knockback until the next round. |
| 3 | Skull-o-tron | Core r95, mass 14, flick x4, damping x1.2 | 1 per unit (core + each Skull Ball, cap 4) | yes | 3 arms (75 px, ball r38). Spins while moving. A hit on an arm/ball >=650 px/s, or ANY contact between an arm/ball and a pin (arena or Pinhead pin, no speed threshold, no waiting), breaks it off as a Skull Ball (mass 0.7). With no arms its mass x0.3. |
| 3 | Mad Creator | Creator (r60, m3, bounce 0.9) in a 480 px box of 4 breakable walls (8000 health each) | 2 (first flick is always the Creator's) | no | While in the box it flicks itself 150-520 px; where it stops, the floor space under it (Grunt, Speedo, Bumper, Powerhouse) summons that figure in front of the box (max 5 summons). Player hits and explosions break walls. |
Each act picks one of its two bosses at random at run start (no repeats). Boss accuracy is 0.7-0.98 (data), scaled by act only from Ascension 3. "Boss body" tag (Wall pieces, Trangle, Skull-o-tron core, Slime large, Mad Creator): when a Bummer takes one over, its shot must never go off the table.

---

## 8. Enemy AI (`enemy_ai.gd`; every number is an @export on the EnemyAI node)
- **Candidate shots**: for every enemy x every player figure: angle offsets (-10, -5, 0, 5, 10 degrees) x power levels (0.2-0.6 of reference speed 2400 x the figure's power). Shots are shape-cast against figures and arena bodies; walls and pins block; floor patches, Juicer trails, magnet zones and Magnets bend the path (simulated in 0.08 s steps).
- **Prediction**: elastic collision along the line of centres (masses, bounce, knockback multipliers, auras, zones, shell damage), then the slide (damping) vs the distance to the table edge gives a knock-off chance (ramps 70-120% of the way).
- **Score of an attack on a player figure** = 100 (hit) + 100 x knock-off chance + 60 x push toward the edge, minus 300 x chance the shooter itself leaves the table (also x miss chance), minus 20 x power (lowest power that still works wins). Hitting an ally first is -150 unless it is lined up with a player figure behind it (then a chain value). Must beat 40 to count; otherwise a 180 px repositioning flick (away from edges, into auras) or a pass.
- **Ability awareness**: explosions (Bombo/Aggro-bom/Sneaky Bomber/Blastoid: pushed player figures score like hits, pushed allies cost), set-off chains, landmines (see Land Miner), Aggro-bom line-ups, Magnet curves, Pusher pushes, Duwall shell cracking (80 + 60 break, minus toughness), Shieldon wall breaking (+40), Alchemist zones (places its zone at turn start; avoids crossing player zones) and Doused targets, Engineer turrets (placed at combat start and every enemy turn on the best lane-covering spot; penalty for paths through player turret range), Pinhead pin bank shots, Eater (+150 for eating a smaller player figure, -180 for a friend unless it is The Collector's feeder), Energizer (+70 for hitting an ally), Bloodluster kill value x1.6 and bonus flicks, Speedo second shots (only if >=120), Bummer auras (avoid ending in one, -150 for flicking a figure inside one, +100 for shoving an ally out), Glue chains (+60 per extra player figure within 150 px), Blastoid shots (taken when better than its best flick), Crazy Man aura (stays inside), Ghost/Wings wrapping.
- **Bummer takeover**: the same search with inverted goals (+300 for its own figure leaving the table; hits on allies +120, kills +200); boss bodies instead get -2500 x leave chance and rewards for moving away from the Bummer.
- **Tiers**: regular fights (and regular enemies) depth 1; elite fights depth 2 (adds fine angles -7.5..7.5 and powers .25-.55); boss fights depth 3 (adds wide angles +-20/30/45 and powers 0.7/0.8). Combo bonuses (blasts, chains, bank shots) x1 / x1.5 / x2. Thinking budget 700 ms per decision.
- **Aim error**: random within `accuracy`-scaled max 20 degrees (accuracy 1 = perfect).
- **Not modelled**: Crazy Man's bounce boost, Splitter minis' weaker hits, Juicer trails of its own side (ignored), arm sweeps of Skull-o-tron, Trangle's spin.

---

## 9. Ascension (0-11, data-driven)
The level list is `AscensionConfig.level_names` / `level_descriptions` (`max_level` = list size - 1, no cap in code; each system reads its level number from the "Level numbers" exports, e.g. `level_upgraded`). Selector on New Run (a scrolling grid); highest unlocked level saved in `user://ascension.json` (version 2: an older file's level 5+ is shifted up by one on load); winning at the highest unlocked level unlocks the next. Level shown in the top bar ("A3"), saved with the run, recorded in run history, per-level win stats in Run History. Every number is in `resources/ascension_config.tres`.

### Ascension 0 baseline (flat)
4 enemies per regular combat in every act; no act stat multiplier (bosses too); no random enemy finishes/equipment/upgrades; elites: no stat boost, no guaranteed gear, no enemy relic. Still present at level 0: encounter and elite pools, AI depth by tier, boss rules and back walls, the player reward curve (3/2/1 choices, bonus items), event penalties, encounter-FORCED gear (The Setup's Skull, Mirror Match copies of your gear), the act 3 elite "pick 1 of 3 relics" reward.

### Levels (each includes all lower ones)
| Lvl | Name | Effect |
|---|---|---|
| 1 | Geared Enemies | Regular enemies roll gear: finishes and equipment only (act 2: 25% finish, 15% equipment; act 3: 50% / 35%); elites and bosses roll at the next act's rates. No upgrade tiers. |
| 2 | Harsher Events | A lost minigame gives BOTH penalties: extra Grunt AND gear on an enemy. |
| 3 | Rising Threat | Act multipliers return: accuracy x1.05/1.1, flick power x1.1/1.2, mass x1.1/1.25 (acts 2/3); bosses accuracy x1.05/1.1, power x1.1/1.2, mass x1.15/1.3; regular combats 4/5/6 enemies. |
| 4 | Leaner Economy | Shop prices x1.5 (rounded up). |
| 5 | Upgraded Enemies | Enemies with an upgrade tree roll tier 1 on one path (random among combat paths): regular enemies 15% / 30% / 45% by act (`enemy_tier1_chance`). Elites' and bosses' figures use the next act's rates and can reach tier 2 (`elite_tier2_chance` 0 / 25% / 50% of those that rolled, by the shifted act). Figures without a tree (most bosses, summons) get none; no tier 3. Upgrade pips on enemies are bigger with a dark backing. |
| 6 | Hardened Elites | Elite enemies get the EliteConfig stat boost (x1.05 mass/power/accuracy in act 1, 1.0 later) and, in acts 2-3, one guaranteed role-fitting item each (50% equipment / 50% finish). Act 1 elites get no gear. |
| 7 | Fewer Offers | Figure choices capped at 2 (including the boss pick); chance drops halved. |
| 8 | Elite Relics | Elites carry one enemy relic in every act (random from the 7-relic enemy pool); shown in the banner and a red line under the top bar. |
| 9 | Boss Upgrades | The Wall creeps x1.5 faster; Sniper Squad 7 snipers; Trangle spin x1.5 and 3 flicks/turn; Slime splits into 3 at both sizes; Skull-o-tron 4 arms; Mad Creator's Grunt space summons a Bombo. |
| 10 | Bigger Squads | +1 enemy in every regular combat (on top of Level 3's 4/5/6). |
| 11 | Double Boss | After the act 3 boss you fight the other act 3 boss immediately (no rewards between). Winning both wins the run. |

Migration: saved unlock progress and in-progress runs from before the insertion (no version stored) shift a level of 5+ up by one (`AscensionProgress.migrate_level`). Run history entries keep their stored number; older entries (no `asc_version`) at level 5+ display the old name ("Ascension 6 (old: Fewer Offers)") and are counted apart in the per-level stats.

---

## 10. Events and minigames
Events sit on map nodes (1-3 per act); each event appears once per run until all have been seen. All use the shared top bar. A minigame WIN gives $6 plus one random power/equipment/finish; a LOSS sets the minigame penalty (the next combat gets +1 Grunt OR one enemy gets compatible gear; Ascension 2: both; the fight then pays +$5 and an extra item); a tie gives nothing.
| Event | What it is |
|---|---|
| The Trader | Three trades: LOW give a power or an unequipped equipment item for a different random one; MEDIUM give a figure for a random Common/Uncommon figure (shown first); HIGH pay $6 and give 1 figure (get an Uncommon) or 2 (get a Rare) for a figure that comes with a fitting finish, an Upgrade step (pick the first tier afterwards) or item. Deck never below 1 figure. |
| Bocce | 3 Grunts each (3.5x heavier, bounce 0.1), a real flicked jack (radius 24, mass 0.4), coin flip for first throw, closest Grunt to the jack wins. AI opponent. |
| Curling | 2 Banana Peel Grunts each slid at a ring target near the top (rings 250/175/100/35); closest to centre wins. |
| Bowling | 10 pins (4-3-2-1), 3 rounds of 2 flicks each side with a 1.6x heavy ball; most pins wins; a tie goes to the player. |
| Mini-Golf | One ball each (radius 24, mass 0.6, power 0.5) on a random course (Serpentine, Pinball Alley, The Hook), up to 6 strokes each, alternate; first ball in the hole (radius 36, slower than 450 px/s) wins, else nearest. The AI simulates strokes (bank shots included). |
The opponent in the versus games flicks with aim and power error (accuracy 0.6 / golf 0.7).

---

## 11. Menus and screens
- **Main menu**: Continue (if a save exists), New Run (confirm if it would replace a save) -> Ascension selector (unlocked levels, description, stacked summary, Start), Compendium, Run History, Settings (game/menu sound sliders, mute).
- **Map**: scrolling act map, tap a glowing next node; shows a "next fight will be harder" warning when a minigame penalty is set; Autosaves each time it opens.
- **Top bar** (map, combat, shop, reward, event screens): Map button, Inventory button, sound button, "Act n/3  Row r  An", money.
- **Map overlay** (top bar): view-only map with your position and tap-for-description; Close returns.
- **Inventory** (top bar, full screen): roster along the bottom in deck order (tap = full details; drag to reorder outside combat), details box above it, tabs Equipment (drag an item onto a figure to equip, tap an equipped item's badge or the Unequip button to store it), Powers (Discard with confirm, works in combat), Relics (read-only). In combat reordering is locked, and equipping too unless you hold Costume Change (then on your own idle turn). Header has Main menu and Close.
- **Combat**: board, deck strip, turn label, power bar (3 slots), enemy relic line if any, banner (encounter, arena, penalty). Win/loss panel.
- **Reward screen**: steps one at a time (figures draft -> which figure to replace on a deck strip, relics, power, equipment, finish, upgrade), each skippable; lucky drops get a flourish.
- **Shop**, **Trader/minigame event screens** as above; "which figure?" picker uses the deck strip (tap a slot then confirm).
- **Run History**: overall stats, per-Ascension wins, figure stats (most picked / win rate), runs newest first (tap to expand deck, relics, picks).
- **Compendium**: Grunt + every draftable figure by rarity; unseen figures are silhouettes; figure page with a "3D model viewer (coming soon)" placeholder.
- Run saving: autosave on map open; Quit-in-node restarts that node identically (seeded). Combat state and rewards are not saved.

---

## 12. Known bugs, rough edges and differences from prompts

### Differences from what a prompt asked (kept as coded)
- **Pinball Wizard arena**: prompt said "corner-walls layout"; implemented Corner Posts (6 wall segments at the corners). If Open Corners was meant, it is a one-line change in `pinball_wizard.tres`.
- **Ascension 5**: prompt said "fitting gear on every enemy"; act 1 elites get the stat boost but NO gear (EliteConfig `guaranteed_gear` = [false, true, true], from the earlier elite-scaling design).
- **Ascension 0 enemy count**: hand-made encounters with 5 figures (Fireworks, Fortress, Demolition Crew) are trimmed from the end at Ascension 0-2, so their last entry (Magnet / Sneaky Bomber / a Powerhouse) is missing there.
- **Encounter-forced gear stays at Ascension 0** (The Setup's Skull, Mirror Match's copies): treated as encounter design, not random enemy gear.
- **Shops/events start in the 4th row**, not the 3rd (the 3rd row is the chest row).
- **Top bar**: includes a sound button (not in the prompt) and no relic icons (relics live in the Inventory only; there is no relic display during combat).
- **Map screen**: the old "Equipment (N)" button was removed (Inventory replaces it); `equip.tscn` still exists but is unlinked. The old testing-only Upgrades screen and `show_upgrade_screen` toggle were removed.
- **Ascension 10** does not save state between the two bosses: quitting during the second boss and continuing replays the first boss.
- **Run info "Main menu" button** moved from the old overlay into the Inventory header.

### Upgrade trees: interpretations and gaps (2026-11-08)
- Tier effects are cumulative; "x%" changes compound (Blastoid Nuke: power x1.25 then x1.5 then x1.5, radius x0.5 then x0.8). Absolute values ("from +20%") are set, not added.
- Firecracker was removed (Land Miner took its place; saved runs convert it, dropping its upgrades). Enemy explosions push every figure, their own side included.
- Cha-ching: Extra Option = +1 figure choice on the next regular reward screen if it survived; Big Bounty / Bounty Hunter set the knock-off bonus to $4 / $3 (base $1 plus the listed amount); Discount Card is a run modifier while it is in the deck.
- Magnet: Repel Pulse is an instant outward shove (650 px/s at the magnet, fading to half at the edge of its pull range), used by tapping the greyed Magnet after it flicked (once per combat, once per turn with tier 3); Collapse Now is a tap on a flickable Magnet; Black Hole lasts 6 s.
- Piggy Bank: flick power scales by half of the scale gained; Receipts / Big Spender count the share of the money spent this run (`RunManager.money_spent`, saved).
- Splitter Re-Split: a mini splits into 2 smaller minis (80% size) on its first impact after a flick. Juicer Big Splash makes the splash ring 50% wider. Pinhead Two Pins: 2 per turn and 2 on the table; Lasting Pins stay through cycle resets (up to 4); Wet Pins use the normal Alchemist Douse; Bomb Pins: radius 180, force 800, once per pin.
- Absorber Spit: tap the Absorber (uses its action) to spit the oldest held figure at 1500 px/s toward the nearest other figure of ITS OWN team; Spit Bomb: it explodes (radius 170, force 900) on its first impact. Three Stomachs holds 3 (the newest escapes first).
- Ghost: Wrap Gift gives one wrap to every ally the Ghost overlaps during its flick; Teleport is once per turn (tap an empty spot). Energizer: Instant Recharge and Bloodluster Pack Hunter queue a bonus flick that only the player side gets (`Main.grant_bonus_flick`); enemy Energizers just recharge. Stun is "can't flick for a round".
- Enemy AI: it uses Magnet push / implode, Absorber spit and Ghost teleport at the start of its turn (simple rules in `ai_wants_tap` / `ai_tap_point`), plans with `get_flick_power_multiplier` (Speedo, Piggy, Ghost, Aggro Rage...) and extra flicks, and sprays/tosses as before. It does NOT model: Rally Edge Guard's inward nudges, Energizer / Bloodluster bonus flicks, Cluster's slide home, Pinhead pin explosions, Engineer rockets, Ghost Wrap Gift.
- Bonus items after combats can no longer roll a finish (the old "upgrade_item" gave a finish or an upgrade); finishes still come from the shop, bosses, elites and chance drops.

### Inconsistencies and rough edges
- Static descriptions do not mention Ascension changes (Slime "two", Skull-o-tron "three arms", Trangle "twice a turn", Sniper "Five").
- `DifficultyConfig.elite_*` multipliers and `elite_extra_flicks` only apply to the random fallback elite lineup (used only if an act has no elite encounter), so they are effectively unused.
- `RunConfig.enemy_gear` and `AscensionConfig.gear` point at the same resource; the code now reads `AscensionConfig.gear` (fixed in the audit; before it read `RunConfig.enemy_gear`).
- AI does not know Splitter minis hit softer, Trangle's spin, or Skull-o-tron arm sweeps (it treats bosses as circles).
- Drag-and-drop equipping in the Inventory uses Godot's built-in GUI drag (mouse events, also emulated from touch). Tested headless and in screenshots only; not verified with a real finger on a phone.
- Placeholder art/audio: coloured discs with letters and procedural icons, synthesized .wav files, 3D viewer slot empty, no volume sliders in-game besides the Settings menu.
- Compendium does not list non-draftable enemies (Swarmling, Sniper, boss pieces).

### Not implemented (asked for earlier, not present)
- Nothing outstanding that a prompt asked for is known to be missing. Open design questions: whether Open Corners should be the Pinball Wizard arena; whether Ascension 5 act 1 elites should get gear; whether trimmed 5-figure encounters should be redesigned for 4.


## Sandbox mode

Main menu > Sandbox: the real combat scene for fun and playtesting; never touches run saves, unlocks, run history or the Compendium and never ends (no rewards). Strip at the bottom: Setup/Hide, Edit/Play, AI on/off, Free on/off, Menu, Reset, Clear, Pause/Resume, Step. Setup sheet tabs: Arena (all layouts, Boss field, Auto), Figures (side + every figure; tap the board or deck to place; selected figure: Delete, Upgrade path/tier, Finish, Equipment), Boss (any boss, Act 1-3, Ascension 0-10), Fights (any regular or elite encounter), Items (player/enemy relics, player powers; Apply). Edit mode: tap select, drag move. AI off: you flick one enemy figure after each of your flicks. Free flick: any figure any time, no turns. Pause/Step freeze and advance 0.1 s. Lineup figures (boss/encounter) can be moved or deleted live but not gear-edited and return on Reset; powers are player-only. Tested by `tools/sandbox_test.gd`.
