"""Token totals and an API-price estimate for Claude Code transcripts. Run it through
tools/agent-cost.sh (the usage text is there)."""
import argparse
import collections
import datetime
import json
import os
import re
import sys

# Dollars per 1M tokens: (input, output). Cache read 0.1x input, cache write 1.25x (5m) or 2x (1h).
# Source: https://platform.claude.com/docs/en/about-claude/pricing (Model pricing table, read Nov 24):
# Claude Fable 5.2 $8 input / $40 output per MTok, 5m write $10, 1h write $16, cache hits $0.20
# (0.025x input). No long-prompt surcharge listed for Fable. Opus 5.5 and Sonnet 5.5 cache hits are
# listed at $0.20 and $0.10 per MTok, which is 0.05x input.
PRICES = {
    "fable": (8.0, 40.0),
    "opus": (4.0, 20.0),
    "sonnet": (2.0, 10.0),
    "haiku": (0.10, 0.50),
}
# Cache read x input price. Haiku and any model not listed here read at 0.1x. Source: official price
# list (Model pricing table), read Nov 24.
READ_MULT = {"fable": 0.025, "opus": 0.05, "sonnet": 0.05}
HAIKU_LONG = (0.50, 2.50)  # a Haiku call whose prompt is over 100K tokens
LONG_PROMPT = 100_000
GAPS = (5 * 60, 60 * 60)


def parse_time(text):
    text = text.strip()
    now = datetime.datetime.now(datetime.timezone.utc)
    if text and text[-1] in "mhd" and text[:-1].isdigit():
        unit = {"m": "minutes", "h": "hours", "d": "days"}[text[-1]]
        return (now - datetime.timedelta(**{unit: int(text[:-1])})).timestamp()
    if text == "today":
        local = datetime.datetime.now().astimezone()
        return local.replace(hour=0, minute=0, second=0, microsecond=0).timestamp()
    t = datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
    if t.tzinfo is None:
        t = t.astimezone()  # a bare time is local
    return t.timestamp()


def family(model):
    m = str(model or "").lower()
    return next((f for f in PRICES if f in m), None)


def read_calls(root, since, until):
    """Yields one dict per API call, deduplicated by message id + requestId."""
    seen = set()
    for d, _, files in os.walk(root):
        for f in files:
            if not f.endswith(".jsonl"):
                continue
            path = os.path.join(d, f)
            try:
                if os.path.getmtime(path) < since:
                    continue
                fh = open(path, encoding="utf-8", errors="replace")
            except OSError:
                continue
            sub = "/subagents/" in path.replace(os.sep, "/")
            with fh:
                for line in fh:
                    if '"usage"' not in line:
                        continue
                    try:
                        j = json.loads(line)
                    except ValueError:
                        continue
                    m = j.get("message")
                    if not isinstance(m, dict) or not isinstance(m.get("usage"), dict):
                        continue
                    try:
                        t = parse_time(j.get("timestamp", ""))
                    except ValueError:
                        continue
                    if t < since or (until is not None and t >= until):
                        continue
                    mid, rid = m.get("id"), j.get("requestId")
                    if mid:
                        if (mid, rid) in seen:
                            continue
                        seen.add((mid, rid))
                    u = m["usage"]
                    cc = u.get("cache_creation") if isinstance(u.get("cache_creation"), dict) else None
                    cw = u.get("cache_creation_input_tokens") or 0
                    if cc is not None:
                        cw5 = cc.get("ephemeral_5m_input_tokens") or 0
                        cw1 = cc.get("ephemeral_1h_input_tokens") or 0
                    else:
                        cw5, cw1 = cw, 0
                    yield {
                        "path": path, "t": t, "sub": sub, "model": m.get("model"),
                        "in": u.get("input_tokens") or 0, "out": u.get("output_tokens") or 0,
                        "cr": u.get("cache_read_input_tokens") or 0, "cw5": cw5, "cw1": cw1,
                    }


USAGE_RE = re.compile(r"flash usage: (\d+) turns, \d+ s, input (\d+) \+ cache read (\d+) \+ cache write (\d+), "
                      r"output (\d+) tokens")
MODEL_RE = re.compile(r"worker exit \d+, model (\S+?),")


def read_headless(logs, since, until):
    """Yields one dict per headless worker run (flash-<job>.log under logs). A `claude -p` worker
    runs with --no-session-persistence, so it leaves no transcript; its log keeps one usage line
    (turns, input, cache read, cache write, output) and the model. The run counts as one call
    stamped with the log's last-write time; cache write counts as 5m (the log has no split)."""
    for d, _, files in os.walk(logs):
        for f in files:
            if not (f.startswith("flash-") and f.endswith(".log")):
                continue
            path = os.path.join(d, f)
            try:
                t = os.path.getmtime(path)
                text = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if t < since or (until is not None and t >= until):
                continue
            u, m = USAGE_RE.search(text), MODEL_RE.search(text)
            if not u or not m:
                continue
            yield {"path": path, "t": t, "sub": "head", "model": m.group(1),
                   "in": int(u.group(2)), "out": int(u.group(5)), "cr": int(u.group(3)),
                   "cw5": int(u.group(4)), "cw1": 0, "agg": True}


def is_long(c):
    # A headless run is a whole run's totals, not one prompt, so the 100K rule cannot apply to it.
    return not c.get("agg") and c["in"] + c["cr"] + c["cw5"] + c["cw1"] > LONG_PROMPT


def cost(fam, c):
    pi, po = PRICES[fam]
    if fam == "haiku" and is_long(c):
        pi, po = HAIKU_LONG
    return (c["in"] * pi + c["out"] * po + c["cr"] * READ_MULT.get(fam, 0.1) * pi
            + c["cw5"] * 1.25 * pi + c["cw1"] * 2.0 * pi) / 1e6

TIMEOUT_RE = re.compile(r"\btimeout\s+(?:-\S+\s+)*(\d+)")


def is_wait(cmd):
    """An inline wait in a driver's own Bash call: wait-run.sh, an until loop, sleep, or timeout N >= 60."""
    if "wait-run.sh" in cmd or "until " in cmd or "sleep " in cmd:
        return True
    return any(int(n) >= 60 for n in TIMEOUT_RE.findall(cmd))


def read_waits(root, since, until):
    """Returns {subagent transcript path: inline wait count} for the window (tool_use ids counted once)."""
    seen, counts = set(), collections.Counter()
    for d, _, files in os.walk(root):
        if "subagents" not in d.replace(os.sep, "/"):
            continue
        for f in files:
            if not f.endswith(".jsonl"):
                continue
            path = os.path.join(d, f)
            try:
                if os.path.getmtime(path) < since:
                    continue
                fh = open(path, encoding="utf-8", errors="replace")
            except OSError:
                continue
            with fh:
                for line in fh:
                    if '"tool_use"' not in line:
                        continue
                    try:
                        j = json.loads(line)
                        t = parse_time(j.get("timestamp", ""))
                        content = j["message"]["content"]
                    except (ValueError, KeyError, TypeError):
                        continue
                    if t < since or (until is not None and t >= until) or not isinstance(content, list):
                        continue
                    for b in content:
                        if (isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Bash"
                                and isinstance(b.get("input"), dict) and b["id"] not in seen
                                and is_wait(str(b["input"].get("command", "")))):
                            seen.add(b["id"])
                            counts[path] += 1
    return counts


def agent_meta(path):
    try:
        with open(path[:-len(".jsonl")] + ".meta.json", encoding="utf-8") as fh:
            m = json.load(fh)
        return m if isinstance(m, dict) else {}
    except (OSError, ValueError):
        return {}


def agent_label(path):
    return agent_meta(path).get("description") or os.path.basename(path)


def is_waiter(path):
    """An agent whose job is waiting: thumb-wait, or thumb-haiku described as a wait."""
    m = agent_meta(path)
    return m.get("agentType") == "thumb-wait" or (
        m.get("agentType") == "thumb-haiku" and "wait" in str(m.get("description", "")).lower())


def main(argv):
    ap = argparse.ArgumentParser(prog="agent-cost.sh", add_help=False)
    ap.add_argument("--since", required=True)
    ap.add_argument("--until")
    default_root = os.path.join(os.path.expanduser("~"), ".claude", "projects")
    ap.add_argument("--root", default=default_root)
    ap.add_argument("--flash-logs", help="folder searched for flash-*.log headless worker logs "
                    "(default: this repo's docs/briefs when --root is not given; none otherwise)")
    ap.add_argument("--match", default="", help="only transcripts whose path contains this text")
    ap.add_argument("--line", action="store_true")
    try:
        a = ap.parse_args(argv)
        since = parse_time(a.since)
        until = parse_time(a.until) if a.until else None
    except (SystemExit, ValueError) as e:
        print(f"agent-cost: bad arguments ({e})", file=sys.stderr)
        return 2
    if not os.path.isdir(a.root):
        print(f"agent-cost: no folder {a.root}", file=sys.stderr)
        return 2

    keys = ("calls", "in", "out", "cr", "cw5", "cw1", "cost", "long")
    rows = collections.defaultdict(lambda: dict.fromkeys(keys, 0))
    unknown = collections.Counter()
    by_agent = collections.defaultdict(list)
    logs = a.flash_logs
    if logs is None and a.root == default_root:
        logs = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "briefs")
    calls = list(read_calls(a.root, since, until))
    if logs and os.path.isdir(logs):
        calls += list(read_headless(logs, since, until))
    for c in calls:
        if a.match and a.match not in c["path"].replace(os.sep, "/"):
            continue
        fam = family(c["model"])
        if fam is None:
            if c["model"] != "<synthetic>":
                unknown[str(c["model"])] += 1
            continue
        r = rows[(fam, c["sub"] if isinstance(c["sub"], str) else "sub" if c["sub"] else "main")]
        r["calls"] += 1
        for k in ("in", "out", "cr", "cw5", "cw1"):
            r[k] += c[k]
        r["cost"] += cost(fam, c)
        if fam == "haiku" and is_long(c):
            r["long"] += 1
        if fam == "sonnet":
            by_agent[c["path"]].append(c)

    # Sonnet resumes: a call more than 5 / 60 minutes after the same transcript's previous call,
    # and the cache it wrote on those calls.
    gaps = [[0, 0] for _ in GAPS]
    for calls in by_agent.values():
        calls.sort(key=lambda c: c["t"])
        for prev, c in zip(calls, calls[1:]):
            for i, g in enumerate(GAPS):
                if c["t"] - prev["t"] > g:
                    gaps[i][0] += 1
                    gaps[i][1] += c["cw5"] + c["cw1"]

    waits = read_waits(a.root, since, until)
    flagged = sorted(((agent_label(p), n) for p, n in waits.items()
                      if n > 1 and not is_waiter(p) and (not a.match or a.match in p.replace(os.sep, "/"))), key=lambda x: -x[1])
    wait_txt = "inline waits >1: " + (", ".join(f"{k} {n}" for k, n in flagged) or "none")

    total = sum(r["cost"] for r in rows.values())
    fams = collections.OrderedDict()
    for (fam, _), r in sorted(rows.items()):
        f = fams.setdefault(fam, dict.fromkeys(keys, 0))
        for k in keys:
            f[k] += r[k]
    since_txt = datetime.datetime.fromtimestamp(since).strftime("%Y-%m-%d %H:%M")
    gap_txt = (f"sonnet resumes >5m {gaps[0][0]} ({gaps[0][1] / 1e6:.2f}M written), "
               f">60m {gaps[1][0]} ({gaps[1][1] / 1e6:.2f}M written)")
    if a.line:
        parts = [f"{fam} ${f['cost']:.2f} (cw5m {f['cw5'] / 1e6:.2f}M cw1h {f['cw1'] / 1e6:.2f}M)"
                 for fam, f in fams.items()]
        print(f"agent-cost since {since_txt}: " + ", ".join(parts or ["no calls"])
              + f"; total ${total:.2f}; {gap_txt}; inline waits >1: {len(flagged)} agents")
    else:
        print(f"since {since_txt}" + (f", match {a.match}" if a.match else ""))
        print(f"{'MODEL':8} {'WHO':5} {'CALLS':>6} {'IN':>9} {'OUT':>9} {'CREAD':>11} "
              f"{'CW5M':>10} {'CW1H':>10} {'COST':>8}")
        for (fam, who), r in sorted(rows.items()):
            print(f"{fam:8} {who:5} {r['calls']:6} {r['in']:9} {r['out']:9} {r['cr']:11} "
                  f"{r['cw5']:10} {r['cw1']:10} {r['cost']:8.2f}")
        print(f"total ${total:.2f}")
        print(gap_txt)
        print(wait_txt)
        long_calls = fams.get("haiku", {}).get("long", 0)
        if long_calls:
            print(f"haiku calls over {LONG_PROMPT // 1000}K prompt (5x price): {long_calls}")
        for model, n in unknown.most_common():
            print(f"skipped (no price): {model} x{n}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
