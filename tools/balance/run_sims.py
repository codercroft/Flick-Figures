#!/usr/bin/env python3
"""One command for the balance sims.  Examples (from the repo root):

  python3 tools/balance/run_sims.py                      # everything at the default sample sizes (long!)
  python3 tools/balance/run_sims.py --sims 1 --fights 10 # just the figure-strength sim, 10 fights per matchup
  python3 tools/balance/run_sims.py --sims 4 --runs-a0 20 --runs-a5 10 --policy random
  python3 tools/balance/run_sims.py --sims 3 --decks my_decks.json --filter Boss
  python3 tools/balance/run_sims.py --report-only        # rebuild BALANCE_REPORT.md from the CSVs already in tools/balance
  python3 tools/balance/run_sims.py --check-ai           # does enemy_ai.gd still choose the same shots as the saved baseline?
  python3 tools/balance/run_sims.py --check-speed 6      # does the fast mode give the same fights as real time? (6 fights per mode)

What it does: starts --jobs godot workers in parallel (each plays a share of the fights headless, with fixed seeds so a run can
be repeated exactly), merges their CSVs into tools/balance/, writes BALANCE_REPORT.md and a meta.json with the settings and the
wall-clock times. user:// is pointed at a throw-away folder for every worker: the sims can never read or write your real saves,
unlocks or run history. Nothing here changes a balance value; a sim only plays the game as it is."""
import argparse
import csv
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

IGNORED_LOG = re.compile(r"^\s+at: |Compile Error|Identifier not found|reload \(|Failed to load|at: load|^\s*$|Godot Engine|ObjectDB|resources still in use|at: cleanup|at: clear|leaked at exit")


def mode_args(mode):
    """The engine arguments and worker options for a speed mode. 'fixed' = one physics step per frame as fast as the CPU goes
    (--fixed-fps 60: the game's own 1/60 s steps, no real-time wait); 'realtime' = normal speed; 'xN' = Engine.time_scale N."""
    if mode == "fixed":
        return ["--fixed-fps", "60"], []
    if mode == "realtime":
        return [], []
    if mode.startswith("x"):
        return [], ["--scale=%s" % mode[1:]]
    raise SystemExit("unknown --mode " + mode)


def start_workers(args, sim, tmp, extra, mode, jobs, tag):
    engine, worker_opts = mode_args(mode)
    procs = []
    for k in range(jobs):
        out = os.path.join(tmp, "%s_%d.csv" % (tag, k))
        log = open(os.path.join(tmp, "%s_%d.log" % (tag, k)), "w")
        env = dict(os.environ)
        env["XDG_DATA_HOME"] = os.path.join(tmp, "balance_sim_home_%d" % k)
        cmd = [args.godot, "--headless"] + engine + ["--path", ROOT, "-s", "tools/balance/sim_worker.gd", "--",
               "--sim=%s" % sim, "--shard=%d/%d" % (k, jobs), "--out=%s" % out, "--seed=%d" % args.seed,
               "--accuracy=%s" % args.accuracy] + worker_opts + extra
        procs.append((subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, env=env, cwd=ROOT), log, out, k))
    return procs


def wait(procs, label):
    started = time.time()
    while any(p.poll() is None for p, _, _, _ in procs):
        time.sleep(5)
        print("\r%s: running %ds" % (label, time.time() - started), end="", flush=True)
    print("\r%s: finished in %ds        " % (label, time.time() - started))
    for p, log, _, _ in procs:
        log.close()
    return time.time() - started


def merge(parts, dest):
    """Concatenates worker CSVs (skipping repeated headers). Returns the number of data rows."""
    rows = 0
    header = None
    with open(dest, "w", newline="") as out:
        for part in parts:
            if not os.path.exists(part):
                continue
            with open(part, newline="") as f:
                lines = f.read().splitlines(True)
            if not lines:
                continue
            if header is None:
                header = lines[0]
                out.write(header)
            for line in lines[1:]:
                out.write(line)
                rows += 1
    return rows


def scan_logs(tmp, tag):
    """Lines in the worker logs that point at something that broke (the usual start-up noise is ignored)."""
    found = {}
    for path in glob.glob(os.path.join(tmp, "%s_*.log" % tag)):
        for line in open(path, errors="replace"):
            line = line.rstrip()
            if IGNORED_LOG.search(line):
                continue
            if line.startswith(("job ", "run ", "sim ")):
                continue
            key = re.sub(r"\d+", "N", line)[:200]
            found[key] = found.get(key, 0) + 1
    return found


def run_fight_sim(args, sim, tmp, meta, dest_name, extra=None):
    extra = list(extra or [])
    extra += ["--fights=%d" % args.fights, "--acts=%s" % args.acts]
    if args.filter:
        extra.append("--filter=%s" % args.filter)
    if args.decks and sim == "3":
        extra.append("--decks=%s" % args.decks)
    tag = "sim%s" % sim
    procs = start_workers(args, sim, tmp, extra, args.mode, args.jobs, tag)
    seconds = wait(procs, "sim %s" % sim)
    rows = merge([out for _, _, out, _ in procs], os.path.join(args.out, dest_name))
    meta["sims"][sim] = {"rows": rows, "wall_seconds": round(seconds), "fights_per_matchup": args.fights, "jobs": args.jobs, "mode": args.mode}
    meta["log_findings"][sim] = scan_logs(tmp, tag)


def run_run_sim(args, tmp, meta, ascension, runs):
    if runs <= 0:
        return
    tag = "sim4_a%d" % ascension
    extra = ["--runs=%d" % runs, "--ascension=%d" % ascension, "--policy=%s" % args.policy]
    procs = start_workers(args, "4", tmp, extra, args.mode, args.jobs, tag)
    seconds = wait(procs, "sim 4 (Ascension %d, %d runs)" % (ascension, runs))
    for kind in ("runs", "nodes", "picks", "shop"):
        merge([out.replace(".csv", "_%s.csv" % kind) for _, _, out, _ in procs], os.path.join(args.out, "sim4_a%d_%s.csv" % (ascension, kind)))
    meta["sims"]["4_a%d" % ascension] = {"runs": runs, "wall_seconds": round(seconds), "jobs": args.jobs, "mode": args.mode, "policy": args.policy}
    meta["log_findings"]["4_a%d" % ascension] = scan_logs(tmp, tag)


def check_ai(args, tmp):
    out = os.path.join(tmp, "ai_now.json")
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = os.path.join(tmp, "balance_sim_home_ai")
    subprocess.run([args.godot, "--headless", "--path", ROOT, "-s", "tools/balance/ai_regression.gd", "--", "--out=" + out, "--count=60"],
                   env=env, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1800)
    base_path = os.path.join(HERE, "ai_regression_baseline.json")
    if args.update_ai_baseline:
        shutil.copy(out, base_path)
        print("baseline updated:", base_path)
        return 0
    base = json.load(open(base_path))
    now = json.load(open(out))
    strip = lambda r: {k: v for k, v in r.items() if k != "ms"}
    diffs = [i for i, (a, b) in enumerate(zip(base, now)) if strip(a) != strip(b)]
    print("AI check: %d positions, %d differ%s" % (len(base), len(diffs), (": " + str(diffs)) if diffs else " (identical)"))
    return 1 if diffs else 0


def check_speed(args, tmp):
    """Same fights (same seeds) in real time and in the fast modes; compares each fight's outcome."""
    n = int(args.check_speed)
    modes = args.speed_modes.split(",")
    results = {}
    for mode in modes:
        tag = "speed_%s" % mode
        extra = ["--fights=%d" % n, "--acts=1", "--filter=%s" % args.speed_filter]
        procs = start_workers(args, "1", tmp, extra, mode, 1, tag)
        secs = wait(procs, "speed check, mode %s" % mode)
        merge([out for _, _, out, _ in procs], os.path.join(tmp, tag + ".csv"))
        results[mode] = {"seconds": secs, "rows": list(csv.DictReader(open(os.path.join(tmp, tag + ".csv"))))}
    dest = os.path.join(args.out, "speed_check.csv")
    base_mode = modes[0]
    with open(dest, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mode", "wall_seconds", "fights", "wins", "same_outcome_as_" + base_mode, "same_figures_lost", "same_turns", "avg_sim_seconds"])
        for mode in modes:
            rows, base = results[mode]["rows"], results[base_mode]["rows"]
            same = sum(1 for a, b in zip(rows, base) if a["win"] == b["win"])
            same_lost = sum(1 for a, b in zip(rows, base) if a["figures_lost"] == b["figures_lost"])
            same_turns = sum(1 for a, b in zip(rows, base) if a["player_turns"] == b["player_turns"])
            w.writerow([mode, round(results[mode]["seconds"]), len(rows), sum(int(r["win"]) for r in rows), same, same_lost, same_turns,
                        round(sum(float(r["sim_seconds"]) for r in rows) / max(len(rows), 1), 1)])
    print(open(dest).read())
    return 0


def main():
    ap = argparse.ArgumentParser(description="Balance simulations (see the docstring at the top of this file).")
    ap.add_argument("--sims", default="1,2,3,4", help="which sims: 1 figure strength, 2 upgrade paths, 3 decks vs encounters/elites/bosses, 4 full runs")
    ap.add_argument("--fights", type=int, default=50, help="fights per matchup in sims 1-3")
    ap.add_argument("--runs-a0", type=int, default=200, help="full runs at Ascension 0 (sim 4)")
    ap.add_argument("--runs-a5", type=int, default=100, help="full runs at Ascension 5 (sim 4)")
    ap.add_argument("--jobs", type=int, default=max(os.cpu_count() or 1, 1), help="parallel godot workers")
    ap.add_argument("--filter", default="", help="only subjects / targets whose name contains this text")
    ap.add_argument("--acts", default="1,2,3", help="acts to cover in sims 1-3")
    ap.add_argument("--seed", type=int, default=1, help="base seed: the same seed and settings give the same fights")
    ap.add_argument("--accuracy", type=float, default=0.85, help="the bot's aim accuracy")
    ap.add_argument("--policy", default="rarity", help="draft / shop policy for sim 4 (rarity, random, or your own in run_sim.gd)")
    ap.add_argument("--decks", default="", help="decks file for sim 3 (default tools/balance/decks.json)")
    ap.add_argument("--mode", default="fixed", help="fixed (default, fastest), realtime, or xN (Engine.time_scale N)")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--out", default=os.path.join(HERE, "data"), help="where the CSVs go (tools/balance/data has a .gdignore, so Godot never imports them as translations)")
    ap.add_argument("--report", default=os.path.join(ROOT, "BALANCE_REPORT.md"))
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--check-ai", action="store_true")
    ap.add_argument("--update-ai-baseline", action="store_true")
    ap.add_argument("--check-speed", default="", help="fights per mode for the speed-equivalence check")
    ap.add_argument("--speed-modes", default="realtime,fixed,x8,x32")
    ap.add_argument("--speed-filter", default="Pusher")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="balance_sim_")
    try:
        if args.check_ai or args.update_ai_baseline:
            return check_ai(args, tmp)
        if args.check_speed:
            return check_speed(args, tmp)
        meta_path = os.path.join(args.out, "meta.json")
        meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {"sims": {}, "log_findings": {}}
        if not args.report_only:
            sims = args.sims.split(",")
            meta["git"] = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
            meta["settings"] = {k: getattr(args, k) for k in ("fights", "seed", "accuracy", "policy", "mode", "jobs", "acts", "filter")}
            meta["finished"] = time.strftime("%Y-%m-%d %H:%M")
            if "1" in sims:
                run_fight_sim(args, "1", tmp, meta, "sim1_figure_strength.csv")
            if "2" in sims:
                run_fight_sim(args, "2", tmp, meta, "sim2_upgrade_paths.csv")
            if "3" in sims:
                run_fight_sim(args, "3", tmp, meta, "sim3_decks.csv")
            if "4" in sims:
                run_run_sim(args, tmp, meta, 0, args.runs_a0)
                run_run_sim(args, tmp, meta, 5, args.runs_a5)
            json.dump(meta, open(meta_path, "w"), indent=2)
        import make_report
        make_report.write(args.out, args.report, meta)
        print("report written:", args.report)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
