"""Effect sprite sheets from the art-drafts branch (2026-11-21), like make_hero_sheets.py.

1. Copies the frames (and the approved rock still) from origin/art-drafts into
   art/effects/ (needs `git fetch origin art-drafts`; files already there are kept).
2. Writes assets/effects/<name>.png: the 9 frames in one row (one view, drawn
   pointing right; the game rotates them to the aim direction), and the rock still.

Run from the project root: python3 tools/once/make_effect_sheets.py
"""
import os
import subprocess

from PIL import Image

DATE = "2026-11-21"
OUT = "assets/effects"
DST = "art/effects"

# game effect -> (art key on art-drafts, frame size)
EFFECTS = {
    "water_lash": ("art/FX-09/FX-09-1+a-tiny-curl-of-water-grows-into-a-large-", (64, 64)),
    "rock_fly": ("art/FX-10/FX-10-2+the-rock-flies-forward-to-the-right-acro", (64, 32)),
    "rock_impact": ("art/FX-10/FX-10-1+the-rock-smashes-into-the-ground-and-bre", (32, 32)),
    "fire_arc": ("art/FX-10/FX-10-4+the-flame-arc-sweeps-around-fast-in-a-ha", (64, 64)),
    "air_palm_spiral": ("art/FX-08/FX-08-5+the-spiral-of-wind-spins-and-shoots-to-t", (64, 64)),
    "air_gust_spiral": ("art/FX-08/FX-08-5+the-spiralling-wind-sweeps-outward-to-th", (64, 64)),
}
# Stills: game name -> art-drafts file (the clean rock; approved/FX-07-1.png, the old
# oversized rock, is not used).
STILLS = {"rock": "approved/FX-10-1.png"}


def fetch(src):
    dst = f"{DST}/{src.split('/', 1)[1]}"
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        data = subprocess.run(["git", "show", f"origin/art-drafts:{src}"], capture_output=True, check=True).stdout
        with open(dst, "wb") as f:
            f.write(data)
    return dst


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (key, size) in EFFECTS.items():
        frames = [Image.open(fetch(f"{key}_{DATE}_{i}.png")).convert("RGBA") for i in range(1, 10)]
        for i, img in enumerate(frames):
            if img.size != size:
                raise SystemExit(f"{name} frame {i + 1}: {img.size}, expected {size}")
        sheet = Image.new("RGBA", (size[0] * 9, size[1]))
        for i, img in enumerate(frames):
            sheet.alpha_composite(img, (i * size[0], 0))
        sheet.save(f"{OUT}/{name}.png")
        print(f"wrote {OUT}/{name}.png ({size[0]}x{size[1]} x 9)")
    for name, src in STILLS.items():
        img = Image.open(fetch(src)).convert("RGBA")
        img.save(f"{OUT}/{name}.png")
        print(f"wrote {OUT}/{name}.png ({img.size[0]}x{img.size[1]}, drawn {img.getbbox()})")


if __name__ == "__main__":
    main()
