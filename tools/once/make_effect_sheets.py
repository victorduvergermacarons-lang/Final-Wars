"""Effect sprite sheets from the art-drafts branch (2026-11-21), like make_hero_sheets.py.

1. Copies the frames (and the approved rock still) from origin/art-drafts into
   art/effects/ (needs `git fetch origin art-drafts`; files already there are kept).
2. Writes assets/effects/<name>.png: the 9 frames in one row (one view, drawn
   pointing right; the game rotates them to the aim direction), and the rock still.

3. (Stance rework phase 3, 2026-11-23) Every approved ability effect (PIECES):
   - copies approved/<KEY>.png (only approved art is used) to art/effects/ and
     assets/effects/<name>.png;
   - when the art bot has made frames for a piece (art/<ID>/<KEY>+<action>_<date>_<n>.png
     on art-drafts), uses the newest set instead: one row of frames, and the FxDef's
     `frames` is set to their count;
   - writes content/effects/<name>.tres when it doesn't exist yet (pivot, motion,
     anchor... from PIECES; edit the .tres afterwards, it is never overwritten);
   - for pieces that turn with their flight (`rotate`), writes assets/effects/<name>_rot.png:
     the art turned to ROT_STEPS angles with RotSprite (Scale2x three times, turned with
     nearest sampling, read back at the original size), so it never blurs. The drawn
     direction and pivot are read from the .tres.

Run from the project root: python3 tools/once/make_effect_sheets.py
"""
import math
import re
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
# Stance looks (2026-11-23): approved stills only, moved in code (FxDef "Held around
# a hero"). Unapproved ones (FX-15-9, -10, -13, -14, -15, -16, the dragon) draw a
# faint ring instead until they are approved.
STILLS.update({
    "stance_fire_ring": "approved/FX-15-2.png",
    "stance_fire_ribbon": "approved/FX-15-1.png",
    "stance_fire_heels": "approved/FX-15-3.png",
    "stance_fire_sun": "approved/FX-15-4.png",
    "stance_water_hoop": "approved/FX-15-11.png",
    "stance_water_sphere": "approved/FX-15-12.png",
    "stance_air_column": "approved/FX-15-17.png",
    "stance_octopus": "approved/FX-13-21.png",
    "stance_air_ball": "approved/FX-14-5.png",
})


def fetch(src):
    dst = f"{DST}/{src.split('/', 1)[1]}"
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        data = subprocess.run(["git", "show", f"origin/art-drafts:{src}"], capture_output=True, check=True).stdout
        with open(dst, "wb") as f:
            f.write(data)
    return dst


# Motion: 0 none, 1 spin, 2 bob, 3 orbit, 4 flicker, 5 sway, 6 pulse, 7 drop.
# Anchor: 0 at the caster (toward its target), 1 at a point (the target or aim).
P = dict
PIECES = {
    # Fire
    "fire_punch_burst": P(key="FX-11-1", anchor=1, pivot=(20, 14), h=1.0, hold=0.35, fade=True),
    "fire_dart": P(key="FX-11-2", pivot=(16, 18), h=1.0, rotate=True, drawn=90.0, loop=True),
    "flame_dash_trail": P(key="FX-11-8", anchor=1, pivot=(16, 20), h=0.0, motion=4, hz=6.0, loop=True),
    "jet_propulsion": P(key="FX-11-10", pivot=(16, 6), h=0.0, motion=4, hz=8.0, loop=True),
    "phoenix_kick_ring": P(key="FX-11-12", anchor=1, pivot=(31, 40), h=0.0, hold=0.6, fade=True),
    "fireball": P(key="FX-11-13", pivot=(32, 38), h=1.0, rotate=True, drawn=90.0, loop=True),
    "solar_zenith_halo": P(key="FX-11-14", pivot=(33, 33), h=3.2, motion=6, hz=0.8, behind=True, loop=True),
    "flame_wheel": P(key="FX-11-16", pivot=(32, 30), h=0.4, motion=4, hz=4.0, split=True, loop=True),
    "inferno_flames": P(key="FX-11-17", anchor=1, pivot=(16, 46), h=0.0, motion=4, hz=5.0, loop=True),
    "combustion_blast": P(key="FX-11-19", anchor=1, pivot=(32, 32), h=1.0, hold=0.6, fade=True, motion=6, hz=4.0),
    # Earth
    "metal_shards": P(key="FX-12-3", pivot=(16, 16), h=1.0, rotate=True, drawn=0.0, loop=True),
    "boulder_crush": P(key="FX-12-10", anchor=1, pivot=(32, 46), h=0.0, motion=7, amount=6.0, hold=0.9, fade=True),
    # Water
    "heal_ball": P(key="FX-13-1", pivot=(16, 13), h=1.6, motion=2, hz=1.5, amount=0.1, forward=0.35, loop=True),
    "heal_splash": P(key="FX-13-2", anchor=1, pivot=(32, 50), h=0.0, hold=0.6, fade=True),
    "water_shield": P(key="FX-13-3", pivot=(32, 32), h=2.0, alpha=0.55, motion=6, hz=0.7, loop=True),
    "frost_shard": P(key="FX-13-4", pivot=(16, 16), h=1.0, rotate=True, drawn=-90.0, loop=True),
    "ice_prison": P(key="FX-13-8", pivot=(24, 40), h=0.0, alpha=0.5, loop=True),
    "revive_column": P(key="FX-13-9", anchor=1, pivot=(32, 56), h=0.0, hold=1.2, fade=True, motion=6, hz=2.0),
    "ice_wall": P(key="FX-13-12", anchor=1, pivot=(16, 44), h=0.0, loop=True),
    "spirit_water": P(key="FX-13-13", pivot=(32, 58), h=0.0, alpha=0.85, motion=5, hz=0.6, amount=0.08, loop=True),
    "steam_veil": P(key="FX-13-15", anchor=1, pivot=(16, 28), h=0.0, alpha=0.75, motion=2, hz=0.5, amount=0.1, loop=True),
    "rising_tide_ring": P(key="FX-13-19", pivot=(32, 34), h=0.0, motion=2, hz=0.6, amount=0.08, split=True, loop=True),
    "ice_spikes": P(key="FX-13-20", anchor=1, pivot=(16, 44), h=0.0, hold=1.0, fade=True),
    # Air (see-through like the air spirals)
    "air_blade": P(key="FX-14-1", pivot=(16, 16), h=1.0, alpha=0.8, rotate=True, drawn=30.0, loop=True),
    "air_step_puff": P(key="FX-14-2", pivot=(16, 28), h=0.0, alpha=0.6, motion=6, hz=2.0, behind=True, loop=True),
    "stolen_breath": P(key="FX-14-4", anchor=1, pivot=(16, 16), h=3.5, alpha=0.8, motion=2, hz=1.5, amount=0.15, hold=0.8, fade=True),
    "air_scooter_ball": P(key="FX-14-5", pivot=(16, 26), h=0.0, motion=2, hz=1.2, amount=0.1, loop=True),
    "air_sphere": P(key="FX-14-8", pivot=(32, 32), h=2.0, alpha=0.55, motion=6, hz=0.7, loop=True),
    "wind_walk_swirl": P(key="FX-14-9", pivot=(32, 56), h=0.0, alpha=0.6, hold=0.6, fade=True),
    "vortex": P(key="FX-14-10", anchor=1, pivot=(32, 32), h=0.0, alpha=0.6, hold=1.5, fade=True, motion=6, hz=3.0),
    "updraft": P(key="FX-14-11", anchor=1, pivot=(16, 62), h=0.0, alpha=0.6, hold=1.0, fade=True, motion=4, hz=6.0),
    "suffocate_ring": P(key="FX-14-12", pivot=(16, 16), h=4.2, alpha=0.7, motion=6, hz=1.0, loop=True),
    "tornado": P(key="FX-14-14", pivot=(16, 52), h=0.0, alpha=0.7, motion=4, hz=6.0, loop=True),
    "cyclone_spin": P(key="FX-14-15", pivot=(32, 32), h=0.5, alpha=0.6, motion=4, hz=5.0, split=True, loop=True),
    "hurricane": P(key="FX-14-18", anchor=1, pivot=(16, 30), h=0.0, alpha=0.8, motion=4, hz=4.0, loop=True),
}
ROT_STEPS = 32


def newest_frames(key):
    """The newest frame set the art bot made for `key` ([] if none)."""
    folder = f"art/{key.rsplit('-', 1)[0]}/"
    names = subprocess.run(["git", "ls-tree", "-r", "--name-only", "origin/art-drafts", folder],
                           capture_output=True, text=True).stdout.split()
    sets = {}
    for n in names:
        m = re.match(rf"{re.escape(folder + key)}\+(.+)_(\d{{4}}-\d\d-\d\d)_(\d+)\.png$", n)
        if m:
            sets.setdefault((m.group(2), m.group(1)), []).append((int(m.group(3)), n))
    if not sets:
        return []
    return [n for _, n in sorted(sets[max(sets)])]


def scale2x(px, w, h):
    out = [None] * (4 * w * h)
    for y in range(h):
        for x in range(w):
            e = px[y * w + x]
            b = px[max(y - 1, 0) * w + x]
            d = px[y * w + max(x - 1, 0)]
            f = px[y * w + min(x + 1, w - 1)]
            hh = px[min(y + 1, h - 1) * w + x]
            e0 = d if (d == b and b != f and d != hh) else e
            e1 = f if (b == f and b != d and f != hh) else e
            e2 = d if (d == hh and d != b and hh != f) else e
            e3 = f if (hh == f and d != hh and b != f) else e
            o = (2 * y) * (2 * w) + 2 * x
            out[o], out[o + 1] = e0, e1
            out[o + 2 * w], out[o + 2 * w + 1] = e2, e3
    return out, 2 * w, 2 * h


def rotsprite_sheet(img, pivot, steps):
    """`steps` cells, cell i turned by i * 360 / steps degrees (screen, clockwise) about
    `pivot`, which sits at each cell's centre."""
    w, h = img.size
    px, bw, bh = list(img.getdata()), w, h
    for _ in range(3):
        px, bw, bh = scale2x(px, bw, bh)
    corners = [(0, 0), (w, 0), (0, h), (w, h)]
    r = max(math.hypot(cx - pivot[0], cy - pivot[1]) for cx, cy in corners)
    cell = int(math.ceil(r)) * 2 + 2
    sheet = Image.new("RGBA", (cell * steps, cell))
    for i in range(steps):
        a = math.radians(i * 360.0 / steps)
        ca, sa = math.cos(a), math.sin(a)
        for cy in range(cell):
            for cx in range(cell):
                dx, dy = cx + 0.5 - cell / 2, cy + 0.5 - cell / 2
                # Back from the turned cell to the art (turn by -a).
                sx = pivot[0] + dx * ca + dy * sa
                sy = pivot[1] - dx * sa + dy * ca
                ux, uy = int(math.floor(sx * 8)), int(math.floor(sy * 8))
                if 0 <= ux < bw and 0 <= uy < bh:
                    sheet.putpixel((i * cell + cx, cy), px[uy * bw + ux])
    return sheet, cell


def write_fx(name, p, size, frames):
    path = f"content/effects/{name}.tres"
    if os.path.exists(path):
        return path
    rot = p.get("rotate", False)
    lines = [
        '[gd_resource type="Resource" script_class="FxDef" format=3]', "",
        '[ext_resource type="Script" path="res://data/defs/fx_def.gd" id="1_fx"]',
        f'[ext_resource type="Texture2D" path="res://assets/effects/{name}.png" id="2_sheet"]',
    ]
    if rot:
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/effects/{name}_rot.png" id="3_rot"]')
    lines += ["", "[resource]", 'script = ExtResource("1_fx")', f'id = &"{name}"', 'sheet = ExtResource("2_sheet")',
              f"frame_size = Vector2i({size[0]}, {size[1]})", f"frames = {frames}", f"fps = {12.0 if frames > 1 else 1.0}",
              f"loop = {'true' if p.get('loop') else 'false'}", f"pivot = Vector2({p['pivot'][0]}, {p['pivot'][1]})",
              f"anchor = {p.get('anchor', 0)}", f"forward_tiles = {p.get('forward', 0.0)}",
              f"height_levels = {p.get('h', 1.0)}", f"rotate = {'true' if rot else 'false'}",
              f"alpha = {p.get('alpha', 1.0)}", f"hold_seconds = {p.get('hold', 0.0)}",
              f"fade_out = {'true' if p.get('fade') else 'false'}", f"drawn_angle = {p.get('drawn', 0.0)}"]
    if rot:
        lines += ['rot_sheet = ExtResource("3_rot")', f"rot_steps = {ROT_STEPS}"]
    lines += [f"motion = {p.get('motion', 0)}", f"motion_hz = {p.get('hz', 0.5)}",
              f"motion_amount = {p.get('amount', 0.1)}",
              f"split = {'true' if p.get('split') else 'false'}", f"behind = {'true' if p.get('behind') else 'false'}"]
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {path}")
    return path


def read_tres(path, field, default):
    m = re.search(rf"^{field} = (.+)$", open(path).read(), re.M)
    return m.group(1) if m else default


def pieces():
    for name, p in PIECES.items():
        frames = newest_frames(p["key"])
        if frames:
            imgs = [Image.open(fetch(n)).convert("RGBA") for n in frames]
            size = imgs[0].size
            sheet = Image.new("RGBA", (size[0] * len(imgs), size[1]))
            for i, img in enumerate(imgs):
                sheet.alpha_composite(img, (i * size[0], 0))
        else:
            sheet = Image.open(fetch(f"approved/{p['key']}.png")).convert("RGBA")
            size = sheet.size
        sheet.save(f"{OUT}/{name}.png")
        path = write_fx(name, p, size, len(frames) or 1)
        if frames and read_tres(path, "frames", "1") != str(len(frames)):
            text = re.sub(r"^frames = \d+$", f"frames = {len(frames)}", open(path).read(), flags=re.M)
            open(path, "w").write(text)
        if p.get("rotate"):
            pv = [float(v) for v in re.findall(r"[-\d.]+", read_tres(path, "pivot", "Vector2(16, 16)"))]
            first = sheet.crop((0, 0, size[0], size[1]))
            rot, cell = rotsprite_sheet(first, pv, ROT_STEPS)
            rot.save(f"{OUT}/{name}_rot.png")
            print(f"wrote {OUT}/{name}_rot.png ({ROT_STEPS} x {cell}px)")
        print(f"{name}: {p['key']} {'%d frames' % len(frames) if frames else 'still (code motion)'}")


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
    pieces()


if __name__ == "__main__":
    main()
