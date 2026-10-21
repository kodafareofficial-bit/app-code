#!/usr/bin/env python3
"""Generates the default logo assets (assets/logo.png, assets/logo_foreground.png).
Skipped if the files already exist, so put your own logo there to override. Needs: pip install pillow"""
import pathlib
from PIL import Image, ImageDraw

out = pathlib.Path("assets")
out.mkdir(exist_ok=True)
if (out / "logo.png").exists() and (out / "logo_foreground.png").exists():
    print("logo assets already present")
    raise SystemExit(0)

S = 2048
c1, c2 = (108, 77, 255), (0, 194, 168)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


g = Image.new("RGB", (256, 256))
px = g.load()
for y in range(256):
    for x in range(256):
        t = (x * 0.35 + (255 - y) * 0.65) / 255.0
        px[x, y] = lerp(c1, c2, min(1, max(0, t)))
bg = g.resize((S, S), Image.BICUBIC)


def glyph(draw, color, scale=1.0):
    cx = cy = S / 2
    w = int(92 * scale)

    def P(x, y):
        return (cx + (x - 512) * 2 * scale, cy + (y - 512) * 2 * scale)

    for seg in [[(400, 380), (290, 512), (400, 644)], [(624, 380), (734, 512), (624, 644)], [(566, 336), (458, 688)]]:
        pts = [P(*p) for p in seg]
        draw.line(pts, fill=color, width=w, joint="curve")
        for p in pts:
            draw.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=color)


full = bg.copy()
glyph(ImageDraw.Draw(full), (255, 255, 255), 1.0)
full.resize((1024, 1024), Image.LANCZOS).save(out / "logo.png")

fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
glyph(ImageDraw.Draw(fg), (255, 255, 255, 255), 0.78)
fg.resize((1024, 1024), Image.LANCZOS).save(out / "logo_foreground.png")
print("default logo generated")
