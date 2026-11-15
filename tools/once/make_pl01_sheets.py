"""Cuts the approved PL-01-1 hero art (art/heroes/PL-01-1/, from the art-drafts
branch, approved 2026-11-15) into game sheets: assets/heroes/pl01/<anim>.png,
48x48 frames, one row per facing: sw, se, nw, ne (CreatureArtDef.rows).

The art faces south-east only. South-west mirrors it. Facing away (nw, ne):
the approved back stills for idle, run, cast and hit (no back animations yet);
death, downed and revived use the front frames (mirrored for nw), since a hero
lying on the ground reads fine either way.

Run from the project root: python3 tools/once/make_pl01_sheets.py
"""
from PIL import Image, ImageOps
import os

SRC = "art/heroes/PL-01-1"
OUT = "assets/heroes/pl01"
F = 48
ANIMS = {"idle": "idle", "run": "walk", "cast": "cast", "hit": "getting-hit",
         "death": "death", "downed": "downed", "revived": "revived"}
FRONT_EVERYWHERE = {"death", "downed", "revived"}

os.makedirs(OUT, exist_ok=True)
stills = {d: Image.open(f"{SRC}/still_{d}.png").convert("RGBA") for d in ("north-east", "north-west")}
for anim, src in ANIMS.items():
    sheet = Image.open(f"{SRC}/{src}.png").convert("RGBA")
    n = sheet.width // F
    frames = [sheet.crop((i * F, 0, (i + 1) * F, F)) for i in range(n)]
    out = Image.new("RGBA", (n * F, 4 * F))
    for i, fr in enumerate(frames):
        mirrored = ImageOps.mirror(fr)
        rows = [mirrored, fr]  # sw, se
        if anim in FRONT_EVERYWHERE:
            rows += [mirrored, fr]  # nw, ne
        else:
            rows += [stills["north-west"], stills["north-east"]]
        for r, img in enumerate(rows):
            out.alpha_composite(img, (i * F, r * F))
    out.save(f"{OUT}/{anim}.png")
    print(anim, n, "frames")
