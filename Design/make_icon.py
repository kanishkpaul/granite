#!/usr/bin/env python3
"""Generates granite's icon sources (concept B, the faceted stone) as SVG.

icon.svg     1024x1024 macOS app icon on the Big Sur/Tahoe grid (824 shape, 100 margin)
mark.svg     the stone alone, transparent, for docs and the README
menubar.svg  a one-colour template of the stone outline for the menu bar
Run it, then `swift render.swift` to make the PNGs in App/Assets.xcassets.
"""
import random

# The stone, from the sketch: six outer corners and one inner vertex the facets meet at.
OUTER = [(65, 20), (105, 48), (97, 102), (53, 116), (21, 82), (29, 36)]
INNER = (67, 66)
# Facet colours, lit from the top left; the blue face is the AI layer (one face of many).
FACETS = [
    ((0, 1), "#aeb1b8"),  # top right
    ((5, 0), "#c3c5cb"),  # top left
    ((4, 5), "#8d9098"),  # left
    ((1, 2), "#3a78d6"),  # right: accent
    ((2, 3), "#6f727a"),  # bottom
    ((3, 4), "#585b63"),  # bottom left
]

def fit(points, size, center, scale):
    xs = [p[0] for p in OUTER]; ys = [p[1] for p in OUTER]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    return [(center[0] + (x - cx) * scale, center[1] + (y - cy) * scale) for x, y in points]

def stone(center, scale, speckles=True, seed=7):
    outer = fit(OUTER, None, center, scale)
    inner = fit([INNER], None, center, scale)[0]
    parts = []
    poly = " ".join(f"{x:.1f},{y:.1f}" for x, y in outer)
    parts.append(f'<clipPath id="stone"><polygon points="{poly}"/></clipPath>')
    for (a, b), color in FACETS:
        pts = [outer[a], outer[b], inner]
        parts.append(f'<polygon points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="{color}"/>')
    if speckles:
        rng = random.Random(seed)
        minx = min(p[0] for p in outer); maxx = max(p[0] for p in outer)
        miny = min(p[1] for p in outer); maxy = max(p[1] for p in outer)
        dots = []
        for _ in range(420):
            x = rng.uniform(minx, maxx); y = rng.uniform(miny, maxy)
            r = rng.choice([1.2, 1.6, 2.2, 2.8, 3.6]) * scale / 6.3
            color, alpha = rng.choice([("#1d1f23", 0.55), ("#ffffff", 0.35), ("#c99a86", 0.55), ("#2b2d31", 0.4)])
            dots.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{color}" fill-opacity="{alpha}"/>')
        parts.append('<g clip-path="url(#stone)">' + "".join(dots) + "</g>")
    # Edges: a faint light line where facets meet reads as polish.
    edges = "".join(f'<line x1="{inner[0]:.1f}" y1="{inner[1]:.1f}" x2="{x:.1f}" y2="{y:.1f}"/>' for x, y in outer)
    parts.append(f'<g stroke="#ffffff" stroke-opacity="0.22" stroke-width="{scale * 0.45:.1f}" stroke-linecap="round">{edges}</g>')
    return "\n".join(parts)

def icon():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f2ee"/><stop offset="1" stop-color="#dedad3"/></linearGradient></defs>
<rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
<ellipse cx="505" cy="778" rx="215" ry="22" fill="#000" fill-opacity="0.10"/>
{stone((512, 500), 5.4)}
</svg>
'''

def mark():
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
{stone((256, 256), 4.6)}
</svg>
'''

def menubar():
    # Template image: black with alpha; the outline and the accent face (spokes are too busy at 18 pt).
    outer = fit(OUTER, None, (18, 18), 0.32)
    inner = fit([INNER], None, (18, 18), 0.32)[0]
    poly = " ".join(f"{x:.2f},{y:.2f}" for x, y in outer)
    lines = "".join(f'<line x1="{inner[0]:.2f}" y1="{inner[1]:.2f}" x2="{x:.2f}" y2="{y:.2f}"/>' for x, y in outer)
    accent = " ".join(f"{x:.2f},{y:.2f}" for x, y in [outer[1], outer[2], inner])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36">
<polygon points="{accent}" fill="#000"/>
<g fill="none" stroke="#000" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"><polygon points="{poly}"/></g>
</svg>
'''

for name, text in [("icon.svg", icon()), ("mark.svg", mark()), ("menubar.svg", menubar())]:
    open(name, "w").write(text)
print("wrote icon.svg, mark.svg, menubar.svg")
