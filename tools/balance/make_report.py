"""Builds BALANCE_REPORT.md from the CSVs run_sims.py leaves in tools/balance/. Run through run_sims.py (it calls write()), or
alone:  python3 tools/balance/run_sims.py --report-only"""
import csv
import json
import math
import os
from collections import Counter, defaultdict


def read(out_dir, name):
    path = os.path.join(out_dir, name)
    if not os.path.exists(path):
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def mean(values):
    values = list(values)
    return sum(values) / len(values) if values else 0.0


def std(values):
    values = list(values)
    if len(values) < 2:
        return 0.0
    m = mean(values)
    return math.sqrt(sum((v - m) ** 2 for v in values) / (len(values) - 1))


def wilson(wins, n, z=1.96):
    if n == 0:
        return 0.0, 0.0
    p = wins / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return max(center - half, 0.0), min(center + half, 1.0)


def pct(x):
    return "%.0f%%" % (100.0 * x)


def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for row in rows:
        lines.append("| " + " | ".join(str(c) for c in row) + " |")
    return "\n".join(lines) + "\n"


def fights_summary(rows):
    n = len(rows)
    wins = sum(int(r["win"]) for r in rows)
    lo, hi = wilson(wins, n)
    return {
        "n": n, "wins": wins, "rate": wins / n if n else 0.0, "ci": "%s-%s" % (pct(lo), pct(hi)),
        "lost": mean(float(r["figures_lost"]) for r in rows), "turns": mean(float(r["player_turns"]) for r in rows),
        "secs": mean(float(r["sim_seconds"]) for r in rows),
    }


def group(rows, key):
    out = defaultdict(list)
    for r in rows:
        out[key(r)].append(r)
    return out


def outliers(named_values, label, sigma=1.5, limit=4):
    """Names whose value is more than `sigma` standard deviations from the mean (top and bottom, at most `limit` each)."""
    values = [v for _, v in named_values]
    if len(values) < 4:
        return []
    m, s = mean(values), std(values)
    if s == 0:
        return []
    ranked = sorted(named_values, key=lambda nv: nv[1])
    low = [nv for nv in ranked if nv[1] < m - sigma * s][:limit]
    high = [nv for nv in reversed(ranked) if nv[1] > m + sigma * s][:limit]
    lines = []
    if high:
        lines.append("%s well above the rest (mean %s): %s." % (label, pct(m), ", ".join("%s %s" % (n, pct(v)) for n, v in high)))
    if low:
        lines.append("%s well below the rest (mean %s): %s." % (label, pct(m), ", ".join("%s %s" % (n, pct(v)) for n, v in low)))
    return lines


def kills_counter(rows):
    total = Counter()
    for r in rows:
        for part in filter(None, r.get("kills_by", "").split("|")):
            name, _, count = part.rpartition(":")
            total[name] += int(count)
    return total


def write(out_dir, report_path, meta):
    s1 = read(out_dir, "sim1_figure_strength.csv")
    s2 = read(out_dir, "sim2_upgrade_paths.csv")
    s3 = read(out_dir, "sim3_decks.csv")
    runs = {a: read(out_dir, "sim4_a%d_runs.csv" % a) for a in (0, 5)}
    nodes = {a: read(out_dir, "sim4_a%d_nodes.csv" % a) for a in (0, 5)}
    picks = {a: read(out_dir, "sim4_a%d_picks.csv" % a) for a in (0, 5)}
    shop = {a: read(out_dir, "sim4_a%d_shop.csv" % a) for a in (0, 5)}
    out = []
    highlights = []
    bugs = []
    st = meta.get("settings", {})

    out.append("# Balance report\n")
    out.append("Generated %s from commit `%s`. Everything below is the game as it is: the sims change no balance value, figure or enemy behaviour.\n"
               % (meta.get("finished", "?"), meta.get("git", "?")))
    out.append("**How to read it.** The bot plays the player side with the enemy AI's own shot evaluation (elite search depth, aim accuracy %s), "
               "fights use fixed seeds, Ascension 0 unless noted. Win rates come with a 95%% interval (Wilson); with few fights per matchup "
               "treat differences under about 10 points as noise.\n" % st.get("accuracy", "0.85"))

    # ---- sim 1 -----------------------------------------------------------------------------------------------------------
    sec1 = []
    if s1:
        by_fig = group(s1, lambda r: r["subject"])
        rows = []
        fig_rate = []
        for fig, rs in by_fig.items():
            sm = fights_summary(rs)
            per_act = {a: fights_summary([r for r in rs if r["act"] == str(a)]) for a in (1, 2, 3)}
            rows.append((sm["rate"], fig, sm, per_act))
            fig_rate.append((fig, sm["rate"]))
        rows.sort(key=lambda x: -x[0])
        sec1.append("## Sim 1: figure strength (figure + 3 Grunts vs each act's regular encounters, Ascension 0)\n")
        sec1.append("The average figure here wins %s of its fights.\n" % pct(mean(v for _, v in fig_rate)))
        sec1.append(table(["Figure", "Fights", "Win rate", "95% CI", "Figures lost", "Player turns", "Act 1", "Act 2", "Act 3"],
                          [(f, sm["n"], pct(sm["rate"]), sm["ci"], "%.2f" % sm["lost"], "%.1f" % sm["turns"],
                            *[pct(pa[a]["rate"]) if pa[a]["n"] else "-" for a in (1, 2, 3)]) for _, f, sm, pa in rows]))
        highlights += outliers(fig_rate, "Figures (sim 1)")
        by_enc = group(s1, lambda r: (r["act"], r["target"]))
        enc_rows = sorted((fights_summary(rs)["rate"], a, t, len(rs)) for (a, t), rs in by_enc.items())
        sec1.append("\nRegular encounters, hardest first (win rate averaged over every figure):\n")
        sec1.append(table(["Encounter", "Act", "Fights", "Win rate"], [(t, a, n, pct(r)) for r, a, t, n in enc_rows]))
        highlights += outliers([("%s (act %s)" % (t, a), r) for r, a, t, n in enc_rows], "Regular encounters (sim 1)", 1.3)

    # ---- sim 2 -----------------------------------------------------------------------------------------------------------
    sec2 = []
    if s2:
        by_fig_base = group([r for r in s1 if r["act"] in ("2", "3")], lambda r: r["subject"])
        base_fig = {f: fights_summary(rs)["rate"] for f, rs in by_fig_base.items()}
        by_path = group(s2, lambda r: r["subject"])
        rows = []
        for name, rs in by_path.items():
            sm = fights_summary(rs)
            fig = rs[0]["figure"]
            delta = sm["rate"] - base_fig[fig] if fig in base_fig else None
            rows.append((delta if delta is not None else -9, name, fig, sm, delta))
        rows.sort(key=lambda x: -x[0])
        sec2.append("## Sim 2: upgrade paths at tier 3 (figure + 3 Grunts vs act 2 and 3 regular encounters)\n")
        sec2.append("`Change` is the win rate minus the same figure with no upgrade against the same acts in sim 1 (blank if sim 1 was not run).\n")
        sec2.append(table(["Figure path", "Fights", "Win rate", "95% CI", "Change vs no upgrade", "Figures lost", "Player turns"],
                          [(n, sm["n"], pct(sm["rate"]), sm["ci"], ("%+.0f pts" % (100 * d)) if d is not None else "", "%.2f" % sm["lost"], "%.1f" % sm["turns"])
                           for _, n, f, sm, d in rows]))
        highlights += outliers([(n, sm["rate"]) for _, n, f, sm, d in rows], "Upgrade paths (sim 2)")
        deltas = [(n, d) for _, n, f, sm, d in rows if d is not None]
        if deltas:
            worst = sorted(deltas, key=lambda x: x[1])[:3]
            best = sorted(deltas, key=lambda x: -x[1])[:3]
            highlights.append("Biggest tier-3 gains over the plain figure: %s. Smallest (or negative): %s." % (
                ", ".join("%s %+.0f pts" % (n, 100 * d) for n, d in best), ", ".join("%s %+.0f pts" % (n, 100 * d) for n, d in worst)))

    # ---- sim 3 -----------------------------------------------------------------------------------------------------------
    sec3 = []
    if s3:
        decks = sorted({r["subject"] for r in s3})
        sec3.append("## Sim 3: mid-run decks vs encounters, elites and bosses\n")
        sec3.append("Decks (edit them in `tools/balance/decks.json`): " + ", ".join(decks) + ".\n")
        by_deck = group(s3, lambda r: r["subject"])
        sec3.append(table(["Deck", "Fights", "Win rate", "95% CI", "Figures lost", "Player turns"],
                          [(d, fights_summary(rs)["n"], pct(fights_summary(rs)["rate"]), fights_summary(rs)["ci"], "%.2f" % fights_summary(rs)["lost"],
                            "%.1f" % fights_summary(rs)["turns"]) for d, rs in by_deck.items()]))
        by_target = group(s3, lambda r: (r["group"], r["act"], r["target"]))
        order = {"regular": 0, "elite": 1, "boss": 2}
        rows = []
        for (g, act, tgt), rs in sorted(by_target.items(), key=lambda kv: (order.get(kv[0][0], 9), kv[0][1], kv[0][2])):
            sm = fights_summary(rs)
            per_deck = []
            for d in decks:
                sub = [r for r in rs if r["subject"] == d]
                per_deck.append(pct(fights_summary(sub)["rate"]) if sub else "-")
            top = kills_counter(rs).most_common(1)
            rows.append((g, act, tgt, sm["n"], pct(sm["rate"]), "%.1f" % sm["turns"], "%.0f" % sm["secs"], ("%s (%d)" % top[0]) if top else "-", *per_deck))
        sec3.append("\nWin rate of each deck against every target. `Turns` is player turns and `Secs` simulated seconds; `Most knock-offs` is the enemy figure that knocked off the most of your figures (credited to the last flicker), with its count over all fights.\n")
        sec3.append(table(["Type", "Act", "Target", "Fights", "Win rate", "Turns", "Secs", "Most knock-offs"] + decks, rows))
        for g in ("regular", "elite", "boss"):
            vals = [(tgt, fights_summary(rs)["rate"]) for (gg, act, tgt), rs in by_target.items() if gg == g]
            highlights += outliers(vals, {"regular": "Regular encounters", "elite": "Elites", "boss": "Bosses"}[g] + " (sim 3)", 1.2)
        weak = sorted((fights_summary(rs)["rate"], tgt) for (g, act, tgt), rs in by_target.items() if g in ("elite", "boss"))[:3]
        if weak:
            highlights.append("Toughest elites / bosses for these decks: " + ", ".join("%s %s" % (t, pct(r)) for r, t in weak) + ".")
        top_all = kills_counter(s3).most_common(5)
        if top_all:
            highlights.append("Enemy figures that knock off the most player figures overall: " + ", ".join("%s (%d)" % kv for kv in top_all) + ". `(own side)` means the figure fell during the player's OWN flick (the bot's shot knocked off or slid off one of its own figures).")
        total_kills = kills_counter(s3)
        if total_kills:
            own = total_kills.get("(own side)", 0) / max(sum(total_kills.values()), 1)
            if own > 0.25:
                highlights.append("About %s of all player figures lost in sim 3 fall during the player's own flick, not the enemy's. Either the bot's mirrored shot evaluation takes too many self-knock-off risks on the player's side (a bot weakness), or flicking is riskier for the player than for the AI (worth a look in the game)." % pct(own))

    # ---- sim 4 -----------------------------------------------------------------------------------------------------------
    sec4 = []
    for a in (0, 5):
        rs = runs[a]
        if not rs:
            continue
        n = len(rs)
        wins = sum(1 for r in rs if r["result"] == "win")
        lo, hi = wilson(wins, n)
        sec4.append("## Sim 4: full runs, Ascension %d (%d runs, policy `%s`)\n" % (a, n, rs[0]["policy"]))
        sec4.append("Win rate **%s** (95%% CI %s-%s). Average act reached %.2f; average nodes played %.1f (%.1f fights). Events are skipped by the bot.\n"
                    % (pct(wins / n), pct(lo), pct(hi), mean(int(r["act_reached"]) for r in rs), mean(int(r["nodes"]) for r in rs), mean(int(r["fights"]) for r in rs)))
        if wins == 0:
            sec4.append("**Caveat:** the bot won no run, and nearly all die in act 1 (see the bot sanity check above), so the pick, money and shop tables below describe the first few nodes only. Treat them as a smoke test of the pipeline, not as balance data, until the bot wins more fights.\n")
        highlights.append("Full runs at Ascension %d: %s won (%d of %d, CI %s-%s)." % (a, pct(wins / n), wins, n, pct(lo), pct(hi)))
        losses = [r for r in rs if r["result"] != "win"]
        if losses:
            sec4.append("\nWhere runs end (losses only):\n")
            by_act = Counter(r["act_reached"] for r in losses)
            by_type = Counter(r["death_type"] for r in losses)
            sec4.append(table(["Act", "Deaths", "Share of all runs"], [("Act %s" % k, by_act[k], pct(by_act[k] / n)) for k in sorted(by_act)]))
            sec4.append(table(["Node type", "Deaths", "Share of all runs"], [(k, v, pct(v / n)) for k, v in by_type.most_common()]))
            by_tgt = Counter(r["death_target"] for r in losses)
            sec4.append(table(["Killed by (encounter / boss)", "Deaths"], by_tgt.most_common(10)))
            top_enc = by_tgt.most_common(1)[0]
            highlights.append("Ascension %d: most runs end against %s (%d of %d deaths)." % (a, top_enc[0], top_enc[1], len(losses)))
        result_of = {r["run"]: r["result"] for r in rs}
        n_win = max(wins, 1)
        n_loss = max(n - wins, 1)
        for kind, title in (("figure", "Figures"), ("relic", "Relics")):
            counts = {"win": Counter(), "loss": Counter()}
            for p in picks[a]:
                if p["kind"] == kind:
                    counts["win" if result_of.get(p["run"]) == "win" else "loss"][p["name"]] += 1
            names = sorted(set(counts["win"]) | set(counts["loss"]), key=lambda x: -(counts["win"][x] + counts["loss"][x]))[:14]
            sec4.append("\nMost-picked %s (picks, and picks per run in winning / losing runs):\n" % title.lower())
            sec4.append(table([title[:-1], "Winning runs", "Losing runs", "Total picks"],
                              [(x, "%d (%.2f per run)" % (counts["win"][x], counts["win"][x] / n_win), "%d (%.2f per run)" % (counts["loss"][x], counts["loss"][x] / n_loss),
                                counts["win"][x] + counts["loss"][x]) for x in names]))
        earned = mean(int(r["money_earned"]) for r in rs)
        spent = mean(int(r["money_spent"]) for r in rs)
        sec4.append("\nMoney per run: earned $%.1f, spent $%.1f (%s of it), left over $%.1f. Winning runs earned $%.1f and spent $%.1f; losing runs earned $%.1f and spent $%.1f.\n" % (
            earned, spent, pct(spent / earned) if earned else "-", mean(int(r["money_end"]) for r in rs),
            mean(int(r["money_earned"]) for r in rs if r["result"] == "win") if wins else 0, mean(int(r["money_spent"]) for r in rs if r["result"] == "win") if wins else 0,
            mean(int(r["money_earned"]) for r in losses) if losses else 0, mean(int(r["money_spent"]) for r in losses) if losses else 0))
        sh = shop[a]
        if sh:
            cat = defaultdict(lambda: [0, 0])
            item = defaultdict(lambda: [0, 0])
            for r in sh:
                cat[r["category"]][0] += 1
                cat[r["category"]][1] += int(r["bought"])
                item[(r["category"], r["item"])][0] += 1
                item[(r["category"], r["item"])][1] += int(r["bought"])
            sec4.append("\nShop items bought ('offered' = in stock in a shop the bot visited):\n")
            sec4.append(table(["Category", "Offered", "Bought", "Bought share"], [(k, v[0], v[1], pct(v[1] / v[0])) for k, v in sorted(cat.items(), key=lambda kv: -kv[1][1])]))
            top_items = sorted(item.items(), key=lambda kv: -kv[1][1])[:15]
            sec4.append(table(["Item", "Offered", "Bought", "Bought share"], [("%s: %s" % k, v[0], v[1], pct(v[1] / v[0])) for k, v in top_items]))
        for r in nodes[a]:
            if r["timeout"] == "1":
                bugs.append("Sim 4 (Ascension %d): a fight against %s timed out." % (a, r["target"]))
        for r in rs:
            if r["anomalies"]:
                bugs.append("Sim 4 (Ascension %d, run %s): %s" % (a, r["run"], r["anomalies"]))

    # ---- anomalies from the fight CSVs and the logs ------------------------------------------------------------------------
    for name, rows in (("1", s1), ("2", s2), ("3", s3)):
        kinds = Counter()
        example = {}
        for r in rows:
            for an in filter(None, r.get("anomalies", "").split("|")):
                if an.startswith("timeout"):
                    continue  # (already reported as a stalemate below)
                key = an.split(" at (")[0]
                kinds[key] += 1
                example.setdefault(key, "%s vs %s" % (r["subject"], r["target"]))
        for k, v in kinds.most_common(6):
            bugs.append("Sim %s: \"%s\" in %d fights (first seen: %s)." % (name, k, v, example[k]))
        stuck = [r for r in rows if r["timeout"] == "1"]
        if stuck:
            by_tgt = Counter("%s (%s)" % (r["target"], r["arena"]) for r in stuck)
            bugs.append("Sim %s: **stalemates**: %d of %d fights had no result after 300 simulated seconds (about 55 turns; a normal fight is 10-30 turns), counted as losses. The game has no turn limit. Most often vs %s; typical reports are 1 player vs 1 enemy figure that cannot hurt each other (a Glue Guy, a Shieldon wall, Mud Flats...)." % (
                name, len(stuck), len(rows), ", ".join("%s x%d" % kv for kv in by_tgt.most_common(5))))
        fallbacks = 0
        late_wins = 0
        for r in rows:
            if r.get("bot_stats", "").startswith("{"):
                st_ = json.loads(r["bot_stats"])
                fallbacks += st_.get("fallback_flicks", 0)
                late_wins += 1 if st_.get("no_enemy_flicks", 0) else 0
        if late_wins:
            bugs.append("Sim %s: in %d fights the last enemy fell AFTER the game's win check (e.g. a delayed explosion such as Sneaky Bomber's), so the fight went on to another player turn and only ended when the player flicked once more. Harmless, but a needless extra turn." % (name, late_wins))
        if rows and fallbacks > 0.05 * len(rows):
            bugs.append("Sim %s: the bot found no shot worth taking and used its fallback nudge %d times in %d fights." % (name, fallbacks, len(rows)))
    for sim, found in meta.get("log_findings", {}).items():
        for line, count in sorted(found.items(), key=lambda kv: -kv[1])[:8]:
            bugs.append("Sim %s log (x%d): `%s`" % (sim, count, line))

    # ---- assemble ----------------------------------------------------------------------------------------------------------
    out.append("## Summary: the biggest outliers\n")
    out.extend(("- " + h) for h in highlights) if highlights else out.append("- (run sims 1-4 to fill this in)")
    out.append("")
    out.append("## Bugs and oddities found during the sims\n")
    out.extend(("- " + b) for b in dict.fromkeys(bugs)) if bugs else out.append("- Nothing broke: no stuck turns, timeouts, crashes or figures far outside the table were recorded in these runs.")
    out.append("")
    out.append("\n".join(sec1))
    out.append("\n".join(sec2))
    out.append("\n".join(sec3))
    out.append("\n".join(sec4))
    out.append("## How these numbers were made\n")
    est = []
    for key, rows, full_per in (("1", s1, 50), ("2", s2, 50), ("3", s3, 50)):
        info = meta.get("sims", {}).get(key)
        if not info or not rows:
            continue
        matchups = len({(r["subject"], r["target"], r["act"]) for r in rows})
        full = matchups * full_per
        est.append(("%s (%d matchups)" % (key, matchups), "%d x %d = %d" % (matchups, info["fights_per_matchup"], len(rows)), "%d x %d = %d" % (matchups, full_per, full),
                    "%.1f min" % (info["wall_seconds"] / 60.0), "%.0f min" % (info["wall_seconds"] * full / len(rows) / 60.0)))
    for a, full_runs in ((0, 200), (5, 100)):
        info = meta.get("sims", {}).get("4_a%d" % a)
        if info and runs.get(a):
            est.append(("4, Ascension %d" % a, "%d runs" % len(runs[a]), "%d runs" % full_runs, "%.1f min" % (info["wall_seconds"] / 60.0), "%.0f min" % (info["wall_seconds"] * full_runs / len(runs[a]) / 60.0)))
    if est:
        out.append("**Sample sizes.** The committed numbers use a smaller sample than the requested 50 fights per matchup / 200 + 100 runs, to fit this session. Full-size time is extrapolated from the wall-clock of the sample (4 workers on a 4-core machine; `python3 tools/balance/run_sims.py` with no options runs the full set).\n")
        out.append(table(["Sim", "Sample", "Full set", "Sample wall-clock", "Full set, estimated"], est))
    bot = read(out_dir, "bot_check.csv")
    if bot:
        out.append("**Bot sanity check** (100 runs at Ascension 0 with the default policy, different bot aim accuracy). The first fight of every run is 4 Grunts against 4 Grunts on a random layout, so a strong bot should win clearly more than half of them. It wins about a third, and perfect aim does not change that: either the player side really starts at a disadvantage against this AI (the figures start on the deck strip, within reach of the enemy's first shot) or the bot plays the mirrored evaluation worse than the AI plays it. Absolute win rates in this report are therefore low; compare rows with each other.\n")
        out.append(table(["Bot accuracy", "First fights", "First-fight wins", "All fights", "All-fight wins", "Runs won", "Runs", "Avg act reached"],
                         [(r["bot_accuracy"], r["first_fights"], r["first_fight_win_pct"] + "%", r["all_fights"], r["all_fights_win_pct"] + "%", r["runs_won"], r["runs"], r["avg_act_reached"]) for r in bot]))
    speed = read(out_dir, "speed_check.csv")
    if speed:
        out.append("**Speed check** (same 30 Pusher-vs-act-1 fights in each mode, same seeds). Fast mode is only used if it gives the same averages as normal speed; single fights can still differ because the game's timers and the physics steps line up differently, so a fight is not bit-identical across modes.\n")
        out.append(table(["Mode", "Fights", "Win %", "Figures lost", "Player turns", "Sim s", "Wall s per fight", "Same win/loss", "Same turns", "Matches normal speed?"],
                         [(r["mode"], r["fights"], r["win_pct"], r["avg_figures_lost"], r["avg_player_turns"], r["avg_sim_seconds"], r["avg_wall_seconds"],
                           r["same_win_loss_as_realtime"], r["same_turns_as_realtime"], r["matches_realtime"]) for r in speed]))
    sims = meta.get("sims", {})
    out.append(table(["Sim", "Rows", "Wall-clock", "Notes"], [(k, v.get("rows", v.get("runs", "")), "%d s" % v["wall_seconds"], "%d workers, mode %s%s" % (
        v["jobs"], v["mode"], (", fights per matchup %d" % v["fights_per_matchup"]) if "fights_per_matchup" in v else "")) for k, v in sims.items()]))
    out.append("""Bot and limits (read before trusting a number):
- The bot is the enemy AI's shot evaluation mirrored for the player (elite depth, aim error from accuracy %s). It is a decent but not perfect player; absolute win rates say more about the bot than about a human. Compare rows with each other.
- Powers: it uses Extra Turn, Super Flick, Bomb Drop, Freeze Ray, Shrink Ray and Rewind; other powers are held unused. Events (the Trader and the four minigames) are skipped in full runs; chests, shops, elites and bosses are played.
- Sim 1 and 2 decks are one figure plus three Grunts, so they measure a figure's contribution to a weak deck, not its best use.
- The AI's search normally stops after 700 real milliseconds; the sims remove that cut-off so a result does not depend on how fast the machine is.
- Re-run with `python3 tools/balance/run_sims.py` (options at the top of that file); CSVs with every fight are next to this file.
""" % st.get("accuracy", "0.85"))
    with open(report_path, "w") as f:
        f.write("\n".join(out))
