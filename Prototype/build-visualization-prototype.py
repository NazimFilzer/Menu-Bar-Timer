#!/usr/bin/env python3
"""Builds Prototype/visualization-and-3d-prototype.html with the 3D renders embedded.

Run after `swift scripts/render-3d-assets.swift`. Sample data only; never reads user logs.
"""
import base64
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "3d"
OUT = ROOT / "visualization-and-3d-prototype.html"


def img(name):
    data = base64.b64encode((ASSETS / f"{name}.png").read_bytes()).decode()
    return f"data:image/png;base64,{data}"


A = {n: img(n) for n in ["stopwatch", "sun", "calendar", "hourglass", "trophy", "flag", "bars", "mug",
                         "stopwatch-orchid", "calendar-orchid", "trophy-orchid", "mug-orchid",
                         "stopwatch-mint", "calendar-mint", "trophy-mint"]}

# ---------- Sample data (matches the preview: 8h day, 40h week, 160h month, ₹1,500/h) ----------
random.seed(7)
GOAL_DAY = 8
RATE = 1500

# October 2026, for the month heatmap, rhythm, histogram and earnings comparison.
oct_days = []  # (day, weekday 0=Mon, hours, start_hour, end_hour, sprints[list of hours])
for d in range(1, 32):
    wd = (3 + d - 1) % 7  # Oct 1 2026 is a Thursday
    if wd >= 5 or d in (2,):
        hours = 0 if wd >= 5 else 0
        if d == 18:
            hours = 2.5
        oct_days.append((d, wd, hours, None, None, [] if hours == 0 else [2.5]))
        continue
    hours = round(random.choice([8.2, 8.5, 7.6, 9.1, 6.4, 8.0, 8.8, 7.9, 5.5, 8.3]), 1)
    start = round(random.uniform(8.6, 10.1) * 4) / 4
    sprints = []
    left = hours
    while left > 0.2:
        s = min(left, round(random.uniform(0.6, 2.4) * 4) / 4)
        sprints.append(s)
        left -= s
    end = start + hours + random.uniform(0.6, 1.3)
    oct_days.append((d, wd, hours, start, end, sprints))

# November so far (preview): Mon 9 = 4h, Tue 10 = 4h30 incl. running sprint.
nov_days = {9: 4.0, 10: 4.5}
nov_today = 10


def fmt_h(h):
    m = int(round(h * 60))
    return f"{m // 60}h {m % 60}m" if m >= 60 else f"{m}m"


def money(v):
    s = f"{v:,.0f}"
    # Indian grouping for the rupee sample
    n = str(int(round(v)))
    if len(n) > 3:
        head, tail = n[:-3], n[-3:]
        parts = []
        while len(head) > 2:
            parts.insert(0, head[-2:])
            head = head[:-2]
        if head:
            parts.insert(0, head)
        s = ",".join(parts) + "," + tail
    return "₹" + s


# ---------- Chart builders (SVG) ----------

def burnup_week():
    W, H, L, R, T, B = 620, 250, 44, 20, 18, 34
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    needed = [8, 16, 24, 32, 40, 40, 40]
    actual = [4, 8.5]
    maxv = 44
    x = lambda i: L + (W - L - R) * (i + 0.5) / 7
    y = lambda v: T + (H - T - B) * (1 - v / maxv)
    g = []
    for v in (0, 10, 20, 30, 40):
        g.append(f'<line x1="{L}" x2="{W-R}" y1="{y(v)}" y2="{y(v)}" class="grid"/>'
                 f'<text x="{L-8}" y="{y(v)+4}" class="axis" text-anchor="end">{v}h</text>')
    for i, d in enumerate(days):
        cls = "axis today" if i == 1 else "axis"
        g.append(f'<text x="{x(i)}" y="{H-12}" class="{cls}" text-anchor="middle">{d}</text>')
    # gap shading between needed and actual up to today
    gap = f'M{x(0)},{y(needed[0])} L{x(1)},{y(needed[1])} L{x(1)},{y(actual[1])} L{x(0)},{y(actual[0])} Z'
    need_path = " ".join(f"{'M' if i == 0 else 'L'}{x(i)},{y(v)}" for i, v in enumerate(needed))
    act_path = " ".join(f"{'M' if i == 0 else 'L'}{x(i)},{y(v)}" for i, v in enumerate(actual))
    # projection at current pace (4.25h/workday) and at needed pace (≈10.5h/workday to Fri)
    proj_cur = f"M{x(1)},{y(8.5)} L{x(4)},{y(8.5 + 3 * 4.25)}"
    proj_need = f"M{x(1)},{y(8.5)} L{x(4)},{y(40)}"
    return f'''<svg viewBox="0 0 {W} {H}" class="chart" role="img" aria-label="Week burn-up: 8h 30m worked, 16h expected by today, 40h goal">
  {''.join(g)}
  <path d="{gap}" class="gap"/>
  <path d="{need_path}" class="needed"/>
  <path d="{proj_need}" class="proj-need"/>
  <path d="{proj_cur}" class="proj"/>
  <path d="{act_path}" class="actual"/>
  {''.join(f'<circle cx="{x(i)}" cy="{y(v)}" r="4" class="dot"/>' for i, v in enumerate(actual))}
  <circle cx="{x(1)}" cy="{y(8.5)}" r="7" class="now"/>
  <text x="{x(4)+6}" y="{y(40)-6}" class="lbl" text-anchor="end">40h goal</text>
  <text x="{x(4)+6}" y="{y(8.5+12.75)+14}" class="lbl muted" text-anchor="end">21h 15m at your pace</text>
  <text x="{x(1)+14}" y="{y(8.5)+18}" class="lbl warn">7h 30m behind plan</text>
</svg>'''


def burnup_month():
    W, H, L, R, T, B = 620, 220, 44, 20, 14, 30
    # November 2026 workdays (Mon–Fri), Nov 1 is Sunday.
    wd = [(1 + d) % 7 for d in range(30)]  # Nov 1 -> 6 (Sun) using Mon=0
    wd = [((6 + d) % 7) for d in range(30)]
    need, acc = [], 0
    for d in range(30):
        if wd[d] < 5:
            acc += GOAL_DAY
        need.append(acc)
    act, a = [], 0
    for d in range(1, nov_today + 1):
        a += nov_days.get(d, 0)
        act.append(a)
    maxv = 180
    x = lambda i: L + (W - L - R) * i / 29
    y = lambda v: T + (H - T - B) * (1 - v / maxv)
    g = []
    for v in (0, 40, 80, 120, 160):
        g.append(f'<line x1="{L}" x2="{W-R}" y1="{y(v)}" y2="{y(v)}" class="grid"/>'
                 f'<text x="{L-8}" y="{y(v)+4}" class="axis" text-anchor="end">{v}h</text>')
    for d in (1, 8, 15, 22, 29):
        g.append(f'<text x="{x(d-1)}" y="{H-10}" class="axis" text-anchor="middle">{d}</text>')
    need_path = " ".join(f"{'M' if i == 0 else 'L'}{x(i)},{y(v)}" for i, v in enumerate(need))
    act_path = " ".join(f"{'M' if i == 0 else 'L'}{x(i)},{y(v)}" for i, v in enumerate(act))
    gap = act_path + " " + " ".join(f"L{x(i)},{y(need[i])}" for i in range(len(act) - 1, -1, -1)) + " Z"
    return f'''<svg viewBox="0 0 {W} {H}" class="chart" role="img" aria-label="Month burn-up">
  {''.join(g)}
  <path d="{gap}" class="gap"/>
  <path d="{need_path}" class="needed"/>
  <path d="{act_path}" class="actual"/>
  <path d="M{x(nov_today-1)},{y(8.5)} L{x(29)},{y(160)}" class="proj-need"/>
  <circle cx="{x(nov_today-1)}" cy="{y(8.5)}" r="6" class="now"/>
  <line x1="{L}" x2="{W-R}" y1="{y(160)}" y2="{y(160)}" class="goal"/>
  <text x="{L+6}" y="{y(160)-6}" class="lbl">160h monthly goal</text>
  <text x="{x(29)}" y="{y(need[-1])-8}" class="lbl muted" text-anchor="end">plan: 8h × {sum(1 for v in wd if v < 5)} workdays</text>
  <text x="{x(nov_today-1)+10}" y="{y(40)}" class="lbl warn">47h 30m behind</text>
</svg>'''


def ribbon(width=520):
    # 24h strip from 6 AM to 6 AM next day is overkill; show 6 AM–10 PM with the forecast.
    start, end = 6, 22
    x = lambda h: (h - start) / (end - start) * width
    blocks = [(6.0, 8.17, "work"), (7.0, 7.17, "pause"), (8.5, 10.75, "work"), (9.5, 9.75, "pause"),
              (13.5, 14.0, "live")]
    parts = []
    for a, b, k in blocks:
        parts.append(f'<rect x="{x(a):.1f}" y="4" width="{x(b)-x(a):.1f}" height="16" rx="3" class="rb-{k}"/>')
    parts.append(f'<rect x="{x(14):.1f}" y="4" width="{x(17.5)-x(14):.1f}" height="16" rx="3" class="rb-forecast"/>')
    parts.append(f'<line x1="{x(14):.1f}" x2="{x(14):.1f}" y1="0" y2="24" class="rb-now"/>')
    ticks = "".join(f'<text x="{x(h):.1f}" y="36" class="axis" text-anchor="middle">{(h-1)%12+1}{"a" if h<12 else "p"}</text>'
                    for h in (6, 10, 14, 18, 22))
    return f'''<svg viewBox="-14 0 {width+28} 40" class="ribbon" role="img" aria-label="Today: two sprints, running since 1:30 PM, finish around 5:30 PM">
  <rect x="0" y="4" width="{width}" height="16" rx="4" class="rb-track"/>{''.join(parts)}{ticks}</svg>'''


def heatmap():
    cells = []
    first_wd = 3  # Thu
    for i in range(first_wd):
        cells.append('<div class="hm-cell blank"></div>')
    for d, wd, h, *_ in oct_days:
        if wd >= 5 and h == 0:
            cells.append(f'<div class="hm-cell off"><span>{d}</span></div>')
            continue
        level = 0 if h == 0 else min(5, int(h / GOAL_DAY * 4) + 1)
        met = h >= GOAL_DAY
        tip = f"Oct {d}: {fmt_h(h)}" if h else f"Oct {d}: no work"
        cells.append(f'<div class="hm-cell l{level}" title="{tip}"><span>{d}</span>'
                     f'{"<i>✓</i>" if met else ""}<b>{fmt_h(h) if h else "—"}</b></div>')
    return ('<div class="hm-head">' + "".join(f"<span>{d}</span>" for d in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
            + '</div><div class="hm-grid">' + "".join(cells) + "</div>")


def rhythm():
    W, H, L, R, T = 620, 170, 44, 20, 28
    hx = lambda h: L + (W - L - R) * (h - 7) / 14
    worked = [d for d in oct_days if d[3] is not None and d[1] < 5]
    row = (H - 40) / len(worked)
    lines = []
    for i, (d, wd, h, s, e, _) in enumerate(worked):
        yy = T + i * row + row / 2
        lines.append(f'<line x1="{hx(s):.1f}" x2="{hx(e):.1f}" y1="{yy:.1f}" y2="{yy:.1f}" class="rh-span"/>'
                     f'<circle cx="{hx(s):.1f}" cy="{yy:.1f}" r="3" class="rh-in"/><circle cx="{hx(e):.1f}" cy="{yy:.1f}" r="3" class="rh-out"/>')
    avg_in = sum(d[3] for d in worked) / len(worked)
    avg_out = sum(d[4] for d in worked) / len(worked)
    ticks = "".join(f'<text x="{hx(h):.1f}" y="{H-8}" class="axis" text-anchor="middle">{(h-1)%12+1} {"AM" if h<12 else "PM"}</text>'
                    for h in (7, 9, 11, 13, 15, 17, 19, 21))
    fmt_clock = lambda v: f"{(int(v)-1)%12+1}:{int(round((v%1)*60)):02d} {'AM' if v < 12 else 'PM'}"
    return f'''<svg viewBox="0 0 {W} {H}" class="chart" role="img" aria-label="Clock-in and clock-out times">
  <line x1="{hx(avg_in):.1f}" x2="{hx(avg_in):.1f}" y1="{T-8}" y2="{H-26}" class="rh-avg"/>
  <line x1="{hx(avg_out):.1f}" x2="{hx(avg_out):.1f}" y1="{T-4}" y2="{H-26}" class="rh-avg"/>
  {''.join(lines)}{ticks}
  <text x="{hx(avg_in)-6:.1f}" y="{T-12}" class="lbl" text-anchor="end">in ≈ {fmt_clock(avg_in)}</text>
  <text x="{hx(avg_out)+6:.1f}" y="{T-12}" class="lbl">out ≈ {fmt_clock(avg_out)}</text>
</svg>''', fmt_clock(avg_in), fmt_clock(avg_out)


def histogram():
    sprints = [s for d in oct_days for s in d[5]]
    bins = [(0, 0.5), (0.5, 1), (1, 1.5), (1.5, 2), (2, 2.5), (2.5, 9)]
    names = ["<30m", "30–60m", "1–1.5h", "1.5–2h", "2–2.5h", "2.5h+"]
    counts = [sum(1 for s in sprints if a <= s < b) for a, b in bins]
    W, H, L, B = 560, 170, 10, 28
    bw = (W - 2 * L) / len(bins)
    mx = max(counts)
    bars = []
    top = counts.index(mx)
    for i, c in enumerate(counts):
        h = (H - B - 18) * c / mx
        cls = "hist hist-top" if i == top else "hist"
        bars.append(f'<rect x="{L + i*bw + 4:.1f}" y="{H-B-h:.1f}" width="{bw-8:.1f}" height="{h:.1f}" rx="4" class="{cls}"/>'
                    f'<text x="{L + i*bw + bw/2:.1f}" y="{H-B-h-5:.1f}" class="lbl" text-anchor="middle">{c}</text>'
                    f'<text x="{L + i*bw + bw/2:.1f}" y="{H-10}" class="axis" text-anchor="middle">{names[i]}</text>')
    return f'<svg viewBox="0 0 {W} {H}" class="chart" role="img" aria-label="Sprint lengths">{"".join(bars)}</svg>', len(sprints), names[top]


def earnings():
    W, H, L, R, T, B = 620, 200, 56, 20, 14, 28
    prev, cur = [], []
    a = 0
    for d, wd, h, *_ in oct_days:
        a += h * RATE
        prev.append(a)
    b = 0
    for d in range(1, 31):
        if d > nov_today:
            break
        b += nov_days.get(d, 0) * RATE
        cur.append(b)
    mx = max(prev) * 1.08
    x = lambda i: L + (W - L - R) * i / 30
    y = lambda v: T + (H - T - B) * (1 - v / mx)
    g = []
    for v in (0, 100000, 200000, 300000):
        if v <= mx:
            g.append(f'<line x1="{L}" x2="{W-R}" y1="{y(v)}" y2="{y(v)}" class="grid"/>'
                     f'<text x="{L-8}" y="{y(v)+4}" class="axis" text-anchor="end">{"₹" + str(v//1000) + "k" if v else "₹0"}</text>')
    pp = " ".join(f"{'M' if i == 0 else 'L'}{x(i):.1f},{y(v):.1f}" for i, v in enumerate(prev))
    cp = " ".join(f"{'M' if i == 0 else 'L'}{x(i):.1f},{y(v):.1f}" for i, v in enumerate(cur))
    same_day_prev = prev[nov_today - 1]
    return f'''<svg viewBox="0 0 {W} {H}" class="chart" role="img" aria-label="Cumulative earnings this month against October">
  {''.join(g)}
  <path d="{pp}" class="ghost"/>
  <path d="{cp} L{x(len(cur)-1):.1f},{y(0)} L{x(0)},{y(0)} Z" class="earn-fill"/>
  <path d="{cp}" class="earn"/>
  <circle cx="{x(len(cur)-1):.1f}" cy="{y(cur[-1]):.1f}" r="5" class="earn-dot"/>
  <circle cx="{x(nov_today-1):.1f}" cy="{y(same_day_prev):.1f}" r="4" class="ghost-dot"/>
  <text x="{x(29):.1f}" y="{y(prev[-1])-8:.1f}" class="lbl muted" text-anchor="end">October {money(prev[-1])}</text>
  <text x="{x(len(cur)-1)+10:.1f}" y="{y(cur[-1])+4:.1f}" class="lbl good">{money(cur[-1])} so far</text>
</svg>''', money(cur[-1]), money(same_day_prev)


def ring(pct, size=15):
    r = size / 2 - 1.6
    c = 2 * math.pi * r
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" class="mb-ring">'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" class="mb-track"/>'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" class="mb-fill" stroke-dasharray="{c*pct:.2f} {c:.2f}" '
            f'transform="rotate(-90 {size/2} {size/2})"/></svg>')


rhythm_svg, avg_in, avg_out = rhythm()
hist_svg, sprint_count, hist_top = histogram()
earn_svg, earn_now, earn_prev = earnings()

# ---------- 3D scope mockups ----------

def popover_idle(art):
    return f'''<div class="pop">
  <div class="pop-head"><span>SKEVAL TIMER</span><span class="cap">Dashboard</span></div>
  <div class="pcard center">
    <img src="{art}" alt="" class="art-lg">
    <div class="ready">Ready</div>
    <div class="muted small">Ready to start your next sprint</div>
    <button class="btn-in">▶ Clock in</button>
  </div>
  <div class="pcard"><div class="h">☀︎ TODAY</div><div class="fig">4h 0m</div><div class="muted small">Work time · 8h goal</div></div>
</div>'''


def reached_card(art):
    return f'''<div class="card reached">
  <img src="{art}" alt="" class="art-md">
  <div><div class="h">WHEN CAN I FINISH?</div>
  <div class="heroTime good">Daily goal reached</div>
  <div class="muted small">8h 12m worked · 12m over · ₹12,300</div></div>
</div>'''


def empty_card(art):
    return f'''<div class="card empty">
  <img src="{art}" alt="" class="art-md">
  <div class="h center">NO SPRINTS YET</div>
  <div class="muted small center">Clock in to start today, or add a sprint you already finished.</div>
  <div class="row center"><button class="btn-in sm">▶ Clock in</button><button class="btn-ghost sm">＋ Add sprint</button></div>
</div>'''


def page_header(art, title, sub):
    return f'''<div class="phead"><img src="{art}" alt="" class="art-head"><div><div class="ptitle">{title}</div><div class="muted small">{sub}</div></div>
  <div class="ph-right"><span class="st">Active</span><span class="mono">00:30:11</span></div></div>'''


def card_header(art, label, value, sub):
    return f'''<div class="card mini"><div class="h3d"><img src="{art}" alt="">{label}</div><div class="fig">{value}</div><div class="muted small">{sub}</div></div>'''


def card_header_sf(icon, label, value, sub):
    return f'''<div class="card mini"><div class="h"><span class="sf">{icon}</span>{label}</div><div class="fig">{value}</div><div class="muted small">{sub}</div></div>'''


html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Skeval Timer · Visualization and 3D prototype</title>
<style>
:root {{
  --ground:#FFFAE6; --card:#FFFFFF; --line:#E8E0BA; --ink:#38301C; --muted:#807552;
  --accent:#E0B24C; --accent-text:#876B2E; --accent-icon:#B48F3D; --wash:rgba(224,178,76,.16);
  --good:#22774D; --mono:ui-monospace, "SF Mono", Menlo, monospace; --rounded:ui-rounded, "SF Pro Rounded", -apple-system, system-ui; --good-fill:#2E9E66; --warn:#995900; --orange:#FF9500; --red:#C15047;
}}
[data-theme=dark] {{
  --ground:#1F1C14; --card:#29291F; --line:#4A4433; --ink:#F2EEE3; --muted:#C9C0A6;
  --accent:#E0B24C; --accent-text:#EBC873; --accent-icon:#E0B24C; --wash:rgba(224,178,76,.14);
  --good:#7FD3A4; --good-fill:#4FBF85; --warn:#FFB54D; --orange:#FF9F0A; --red:#D6594F;
}}
* {{ box-sizing:border-box }}
::selection {{ background:var(--wash); color:var(--ink) }}
body {{ margin:0; background:var(--ground); color:var(--ink); font:13px/1.45 -apple-system, "SF Pro Text", system-ui, sans-serif; }}
.mono, .fig, .axis, .lbl {{ font-family:var(--mono); font-variant-numeric:tabular-nums }}
header.top {{ position:sticky; top:0; z-index:5; display:flex; gap:16px; align-items:center; padding:14px 28px; background:var(--card); border-bottom:1px solid var(--line) }}
header.top h1 {{ font-size:17px; margin:0 }}
header.top .sub {{ color:var(--muted); font-size:12px }}
header.top nav {{ margin-left:auto; display:flex; gap:6px }}
header.top nav a, .toggle {{ font:600 12px var(--rounded); color:var(--ink); text-decoration:none; padding:5px 10px; border-radius:999px; border:1px solid var(--line); background:var(--card); cursor:pointer }}
.toggle[aria-pressed=true] {{ background:var(--accent); color:#000; border-color:var(--accent) }}
main {{ max-width:1180px; margin:0 auto; padding:24px 28px 80px }}
h2 {{ font-size:15px; margin:36px 0 4px }}
h2 + p {{ margin:0 0 16px; color:var(--muted); max-width:70ch }}
.grid2 {{ display:grid; grid-template-columns:repeat(auto-fit, minmax(460px, 1fr)); gap:16px }}
.card {{ background:var(--card); border:1px solid var(--line); border-radius:12px; padding:18px }}
.h, .h3d {{ display:flex; align-items:center; gap:6px; font:700 11px var(--rounded); letter-spacing:.8px; text-transform:uppercase; margin-bottom:10px }}
.h .sf {{ color:var(--accent-icon); font-size:12px }}
.h3d img {{ width:26px; height:26px; margin:-6px 0 -6px -4px }}
.opt {{ display:inline-flex; align-items:center; gap:6px; font:700 10px var(--rounded); letter-spacing:.6px; color:var(--accent-text); background:var(--wash); border:1px solid color-mix(in srgb, var(--accent) 35%, transparent); padding:2px 8px; border-radius:999px; margin-left:auto }}
.why {{ color:var(--muted); font-size:12px; margin:10px 0 0 }}
.why b {{ color:var(--ink) }}
.chart {{ width:100%; height:auto; display:block }}
.grid {{ stroke:var(--line); stroke-width:1 }}
.axis {{ fill:var(--muted); font-size:10px }}
.axis.today {{ fill:var(--accent-text); font-weight:700 }}
.lbl {{ fill:var(--ink); font-size:10.5px; font-weight:700 }}
.lbl.muted {{ fill:var(--muted); font-weight:500 }}
.lbl.warn {{ fill:var(--warn) }}
.lbl.good {{ fill:var(--good) }}
.goal {{ stroke:var(--ink); stroke-width:1; opacity:.35 }}
.needed {{ fill:none; stroke:var(--muted); stroke-width:1.5; stroke-dasharray:4 4 }}
.actual {{ fill:none; stroke:var(--accent); stroke-width:3.5; stroke-linecap:round; stroke-linejoin:round }}
.dot {{ fill:var(--accent) }}
.now {{ fill:var(--card); stroke:var(--accent); stroke-width:3 }}
.gap {{ fill:var(--orange); opacity:.14 }}
.proj {{ fill:none; stroke:var(--accent); stroke-width:2; stroke-dasharray:2 5; stroke-linecap:round; opacity:.8 }}
.proj-need {{ fill:none; stroke:var(--warn); stroke-width:1.5; stroke-dasharray:1 4; stroke-linecap:round }}
.ribbon {{ width:100%; height:auto; display:block }}
.rb-track {{ fill:color-mix(in srgb, var(--line) 45%, transparent) }}
.rb-work {{ fill:var(--accent) }}
.rb-pause {{ fill:var(--orange); opacity:.85 }}
.rb-live {{ fill:var(--accent); }}
.rb-forecast {{ fill:none; stroke:var(--accent); stroke-width:1.5; stroke-dasharray:3 3 }}
.rb-now {{ stroke:var(--ink); stroke-width:1.5 }}
.hm-head, .hm-grid {{ display:grid; grid-template-columns:repeat(7,1fr); gap:5px }}
.hm-head span {{ font:600 10px var(--rounded); color:var(--muted); text-align:center; padding-bottom:4px }}
.hm-cell {{ position:relative; height:52px; border-radius:7px; padding:5px 6px; font-size:10px; border:1px solid var(--line); background:var(--card) }}
.hm-cell span {{ font:600 10px var(--rounded); color:var(--muted) }}
.hm-cell b {{ position:absolute; left:6px; bottom:5px; font:700 10.5px var(--mono); color:var(--ink) }}
.hm-cell i {{ position:absolute; right:6px; top:4px; font-style:normal; font-weight:800; color:var(--good); font-size:10px }}
.hm-cell.blank {{ border:none; background:none }}
.hm-cell.off {{ border-style:dashed; background:none }}
.hm-cell.l0 {{ background:var(--card) }}
.hm-cell.l1 {{ background:color-mix(in srgb, var(--accent) 14%, var(--card)) }}
.hm-cell.l2 {{ background:color-mix(in srgb, var(--accent) 30%, var(--card)) }}
.hm-cell.l3 {{ background:color-mix(in srgb, var(--accent) 48%, var(--card)) }}
.hm-cell.l4 {{ background:color-mix(in srgb, var(--accent) 68%, var(--card)) }}
.hm-cell.l5 {{ background:color-mix(in srgb, var(--accent) 88%, var(--card)) }}
[data-theme=dark] .hm-cell.l4 b, [data-theme=dark] .hm-cell.l5 b {{ color:#1F1C14 }}
.hm-legend {{ display:flex; gap:4px; align-items:center; margin-top:10px; font:500 10px var(--rounded); color:var(--muted) }}
.hm-legend i {{ width:14px; height:10px; border-radius:3px; display:inline-block; border:1px solid var(--line) }}
.rh-span {{ stroke:var(--accent); stroke-width:2.5; opacity:.45; stroke-linecap:round }}
.rh-in {{ fill:var(--accent) }} .rh-out {{ fill:var(--ink) }}
.rh-avg {{ stroke:var(--muted); stroke-dasharray:2 3 }}
.hist {{ fill:color-mix(in srgb, var(--accent) 55%, var(--card)) }} .hist-top {{ fill:var(--accent) }}
.ghost {{ fill:none; stroke:var(--muted); stroke-width:1.5; stroke-dasharray:4 3 }}
.ghost-dot {{ fill:var(--muted) }}
.earn {{ fill:none; stroke:var(--good-fill); stroke-width:3; stroke-linecap:round }}
.earn-fill {{ fill:var(--good-fill); opacity:.1 }}
.earn-dot {{ fill:var(--good-fill) }}
.facts {{ display:flex; gap:28px; margin-top:10px }}
.facts div {{ font:500 11.5px var(--rounded); color:var(--muted) }}
.facts b {{ display:block; font:700 15px var(--mono); color:var(--ink) }}
/* popover */
.pop {{ width:330px; background:var(--ground); border:1px solid var(--line); border-radius:12px; padding:0 0 12px; overflow:hidden }}
.pop-head {{ display:flex; justify-content:space-between; align-items:center; padding:12px 16px; font:700 13px var(--rounded); letter-spacing:1px; border-bottom:1px solid var(--line) }}
.cap {{ font:600 11px var(--rounded); letter-spacing:0; border:1px solid var(--line); border-radius:999px; padding:3px 10px; background:var(--wash) }}
.pcard {{ margin:10px 12px 0; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px }}
.pcard.center, .center {{ text-align:center; justify-content:center }}
.ready {{ font:300 30px var(--mono); margin-top:2px }}
.fig {{ font-size:24px; font-weight:700 }}
.small {{ font-size:11.5px }}
.muted {{ color:var(--muted) }}
.btn-in {{ width:100%; margin-top:10px; border:none; border-radius:8px; padding:9px; font:600 12px var(--rounded); background:var(--accent); color:#000 }}
.btn-in.sm, .btn-ghost.sm {{ width:auto; padding:6px 12px; margin:0 }}
.btn-ghost {{ border:1px solid var(--line); background:var(--card); color:var(--accent-text); border-radius:8px; font:600 12px var(--rounded) }}
.row {{ display:flex; gap:8px; margin-top:12px }}
.art-lg {{ width:92px; height:92px; display:block; margin:-4px auto -2px }}
.art-md {{ width:84px; height:84px }}
.card.reached {{ display:flex; gap:12px; align-items:center }}
.card.empty {{ display:flex; flex-direction:column; align-items:center; gap:4px }}
.heroTime {{ font:600 22px var(--rounded) }}
.good {{ color:var(--good) }}
.phead {{ display:flex; gap:12px; align-items:center; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px 18px }}
.art-head {{ width:48px; height:48px; margin:-6px -2px }}
.ptitle {{ font-weight:700; font-size:17px }}
.ph-right {{ margin-left:auto; text-align:right; display:flex; flex-direction:column; font-size:12px }}
.st {{ font-weight:700; color:var(--accent-text); font-size:11px }}
.card.mini {{ padding:14px }}
.scopes {{ display:grid; grid-template-columns:repeat(3, 1fr); gap:16px; align-items:start }}
.scope {{ display:flex; flex-direction:column; gap:12px }}
.scope > .tag {{ font:700 11px var(--rounded); letter-spacing:.6px; text-transform:uppercase }}
.scope > .note {{ color:var(--muted); font-size:12px; margin-top:-6px }}
.verdict {{ border-left:none; padding:10px 12px; border-radius:8px; background:var(--wash); font-size:12px }}
.minis {{ display:grid; grid-template-columns:1fr 1fr; gap:10px }}
.themes {{ display:flex; gap:14px; align-items:end; flex-wrap:wrap }}
.themes figure {{ margin:0; text-align:center; font:600 10.5px var(--rounded); color:var(--muted) }}
.themes img {{ width:96px; height:96px; display:block }}
.menubar {{ display:flex; gap:22px; align-items:center; padding:8px 14px; border-radius:8px; background:color-mix(in srgb, var(--ink) 6%, var(--card)); border:1px solid var(--line) }}
.pill {{ display:inline-flex; gap:6px; align-items:center; padding:2px 9px; border-radius:999px; font:700 11px var(--mono); background:var(--accent); color:#000 }}
.mb-track {{ fill:none; stroke:rgba(0,0,0,.18); stroke-width:2.2 }}
.mb-fill {{ fill:none; stroke:#000; stroke-width:2.2; stroke-linecap:round }}
.lbl-sm {{ font:500 10.5px var(--rounded); color:var(--muted) }}
@media (max-width: 1000px) {{ .scopes {{ grid-template-columns:1fr }} }}
</style></head>
<body data-theme="light">
<header class="top">
  <div><h1>Visualization and 3D prototype</h1><div class="sub">Skeval Timer v2.3 · Citrus · sample data only</div></div>
  <nav><a href="#charts">Charts</a><a href="#scopes">3D scopes</a><a href="#assets">Assets</a>
  <button class="toggle" id="dark" aria-pressed="false">Dark</button></nav>
</header>
<main>

<section id="charts">
<h2>Six visualizations</h2>
<p>Each one turns a sentence the app prints today into a shape. Pick the ones you want; nothing here is wired into the app yet.</p>
<div class="grid2">

  <div class="card">
    <div class="h"><span class="sf">◔</span>1 · Week burn-up <span class="opt">WEEK · REPLACES PACE TEXT</span></div>
    {burnup_week()}
    <p class="why"><b>Answers:</b> "am I behind, and by how much?" The gold line is what you've worked, the dashed line is the 8h-per-workday plan, and the orange area is the gap. The two dotted lines show where you finish at your pace and the pace you'd need.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">◔</span>1b · Month burn-up <span class="opt">MONTH · BESIDE THE CALENDAR</span></div>
    {burnup_month()}
    <p class="why"><b>Same chart, month scale.</b> The plan line steps flat on weekends, so days off read correctly without a legend.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">▭</span>2 · Day ribbon <span class="opt">POPOVER · UNDER TODAY</span></div>
    <div class="pop" style="width:100%;border:none;padding:0;background:none">
      <div class="pcard" style="margin:0">
        <div style="display:flex;justify-content:space-between;align-items:baseline"><span class="fig">4h 30m</span><span class="mono good" style="font-weight:700;font-size:18px">₹6,750</span></div>
        <div style="margin:10px 0 2px">{ribbon()}</div>
        <div class="small muted">Solid = work · orange = paused · dashed = forecast to <b style="color:var(--ink)">5:30 PM</b></div>
      </div>
    </div>
    <p class="why"><b>The whole day in 20 points of height.</b> It replaces nothing; it sits under the Today figures so one look shows the day's shape, the gaps, and where it ends.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">▦</span>3 · Month heatmap <span class="opt">MONTH · REPLACES BORDER COLOURS</span></div>
    {heatmap()}
    <div class="hm-legend">Less <i class="hm-cell l1" style="height:10px;padding:0"></i><i class="hm-cell l2" style="height:10px;padding:0"></i><i class="hm-cell l3" style="height:10px;padding:0"></i><i class="hm-cell l4" style="height:10px;padding:0"></i><i class="hm-cell l5" style="height:10px;padding:0"></i> More · <b style="color:var(--good)">✓</b> daily goal met · dashed = day off</div>
    <p class="why"><b>October 2026 sample.</b> Fill strength is hours; the check mark is the goal. Meaning no longer rides on colour alone, which fixes the legend problem from the critique.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">⋯</span>4a · Your rhythm <span class="opt">ANALYTICS · SPRINT PATTERNS</span></div>
    {rhythm_svg}
    <p class="why"><b>When do you actually start and stop?</b> One line per workday, from clock-in (gold) to clock-out (ink). Averages: in around <b>{avg_in}</b>, out around <b>{avg_out}</b>.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">▥</span>4b · Sprint lengths <span class="opt">ANALYTICS · SPRINT PATTERNS</span></div>
    {hist_svg}
    <div class="facts"><div><b>{sprint_count}</b>sprints in October</div><div><b>{hist_top}</b>most common length</div></div>
    <p class="why"><b>Pairs with the eye-break reminder.</b> If most sprints run past 2h, a 45-minute reminder is the one that will actually fire.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">₹</span>5 · Cumulative earnings <span class="opt">ANALYTICS · BESIDE TOTALS</span></div>
    {earn_svg}
    <div class="facts"><div><b class="good">{earn_now}</b>November so far</div><div><b>{earn_prev}</b>October by the same day</div></div>
    <p class="why"><b>Answers "how much this month compared with last?"</b> with the previous period as a ghost line, cut to the same day like the Totals card.</p>
  </div>

  <div class="card">
    <div class="h"><span class="sf">◌</span>6 · Menu bar progress ring <span class="opt">MENU BAR · STATUS PILL</span></div>
    <div class="menubar">
      <span class="lbl-sm">Today</span>
      <span class="pill">00:30:11</span>
      <span class="lbl-sm">With the ring</span>
      <span class="pill">{ring(0.56)} 00:30:11</span>
      <span class="pill" style="background:#B87A1F;color:#000">{ring(0.56)} 00:12:40</span>
    </div>
    <p class="why"><b>Daily goal progress without opening the popover.</b> The ring is drawn in the pill's text colour, so it works in every theme. It changes once a minute, so it adds no cost while you work.</p>
  </div>
</div>
</section>

<section id="scopes">
<h2>3D art: the three scopes</h2>
<p>The same SceneKit renders placed three ways. Moments only keeps every figure untouched; the third column shows what "playful everywhere" costs a ledger.</p>
<div class="scopes">
  <div class="scope">
    <div class="tag">A · Moments only <span class="opt" style="margin-left:6px">RECOMMENDED</span></div>
    <div class="note">Idle popover, goal reached, empty states. Figures and charts stay flat.</div>
    {popover_idle(A["stopwatch"])}
    {reached_card(A["trophy"])}
    {empty_card(A["mug"])}
    <div class="verdict">Fits the product rules: art shows up when there's nothing to read, or when there's something to celebrate.</div>
  </div>
  <div class="scope">
    <div class="tag">B · Moments + page headers</div>
    <div class="note">Everything in A, plus one object beside each dashboard page title.</div>
    {page_header(A["sun"], "Today", "Your timer, earnings, and daily sprint history")}
    {page_header(A["flag"], "Week", "Weekly goals and daily work patterns")}
    {page_header(A["calendar"], "Month", "Calendar, pace, and time by tag")}
    {page_header(A["bars"], "Analytics", "Compare any range with the one before")}
    {reached_card(A["trophy"])}
    <div class="verdict">Gives each page an identity at a glance. The header grows about 12 points; the cards are unchanged.</div>
  </div>
  <div class="scope">
    <div class="tag">C · Everywhere playful</div>
    <div class="note">3D objects replace the SF Symbols in every card header too.</div>
    {page_header(A["sun"], "Today", "Your timer, earnings, and daily sprint history")}
    <div class="minis">
      {card_header(A["stopwatch"], "Worked", "4h 30m", "of 8h daily goal")}
      {card_header(A["hourglass"], "Finish", "5:30 PM", "if you keep working")}
      {card_header(A["calendar"], "Month", "8h 30m", "of 160h")}
      {card_header(A["bars"], "Patterns", "2h 0m", "typical sprint")}
    </div>
    <div class="minis">
      {card_header_sf("◷", "Worked", "4h 30m", "of 8h daily goal")}
      {card_header_sf("◔", "Finish", "5:30 PM", "if you keep working")}
    </div>
    <div class="note" style="margin-top:-4px">Bottom row: today's SF Symbol headers, for comparison.</div>
    <div class="verdict">The most fun, but at 26 points the objects blur into blobs and compete with the figures. This one needs PRODUCT.md and DESIGN.md updated.</div>
  </div>
</div>
</section>

<section id="assets">
<h2>The rendered set and theme tinting</h2>
<p>Rendered by <code>scripts/render-3d-assets.swift</code> (SceneKit, headless, Apple frameworks only). Pass an accent hex and every object re-tints to the theme, so all 24 palettes get their own set at build time with no runtime 3D.</p>
<div class="card themes">
  <figure><img src="{A["stopwatch"]}" alt="Stopwatch">Stopwatch</figure>
  <figure><img src="{A["sun"]}" alt="Sun">Sun</figure>
  <figure><img src="{A["calendar"]}" alt="Calendar">Calendar</figure>
  <figure><img src="{A["hourglass"]}" alt="Hourglass">Hourglass</figure>
  <figure><img src="{A["trophy"]}" alt="Trophy">Trophy</figure>
  <figure><img src="{A["flag"]}" alt="Flag">Flag</figure>
  <figure><img src="{A["bars"]}" alt="Bars">Bars</figure>
  <figure><img src="{A["mug"]}" alt="Mug">Mug</figure>
</div>
<div class="card themes" style="margin-top:12px">
  <figure><img src="{A["stopwatch"]}" alt="">Citrus</figure>
  <figure><img src="{A["stopwatch-orchid"]}" alt="">Orchid</figure>
  <figure><img src="{A["stopwatch-mint"]}" alt="">Mint</figure>
  <figure><img src="{A["trophy"]}" alt="">Citrus</figure>
  <figure><img src="{A["trophy-orchid"]}" alt="">Orchid</figure>
  <figure><img src="{A["trophy-mint"]}" alt="">Mint</figure>
  <figure><img src="{A["calendar-orchid"]}" alt="">Orchid</figure>
  <figure><img src="{A["calendar-mint"]}" alt="">Mint</figure>
</div>
</section>
</main>
<script>
const b = document.getElementById('dark');
b.addEventListener('click', () => {{
  const dark = document.body.dataset.theme !== 'dark';
  document.body.dataset.theme = dark ? 'dark' : 'light';
  b.setAttribute('aria-pressed', dark);
}});
</script>
</body></html>
'''
OUT.write_text(html)
print(f"Wrote {OUT} ({OUT.stat().st_size // 1024} KB)")
