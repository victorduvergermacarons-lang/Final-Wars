"""Hero sprite sheets from the approved PL-01-1 art and the PL-02 weapon sets, in
all four facings (2026-11-16; replaces make_pl01_sheets.py, which mirrored the
south-east art).

1. Copies the frames from the art-drafts branch (never merged) into art/heroes/:
     git show origin/art-drafts:art/PL-0x/<file>  ->  art/heroes/PL-0x/<file>
   (needs `git fetch origin art-drafts` first; skipped for files already there).
2. Measures the feet point in each facing on the first idle frame: the two lowest
   blobs are the feet; the feet point is midway between their soles. Facings that
   disagree are shifted by whole pixels onto one common point, FEET, so the hero
   doesn't jump sideways when turning. The weapon sets' characters (PL-02-1 sword,
   PL-02-2 bow) were drawn as edits of PL-01-1, and a scabbard or bow hanging below
   the feet fools the blob test, so for them the script finds the offset that best
   overlays their standing still (PL-02-x_take1_<facing>.png) on PL-01-1's and
   takes PL-01-1's feet through it.
3. Measures the walk stride: the widest gap between the two soles in each facing's
   walk is one step (in screen x; a tile along a grid axis is 16 art px across), a
   9-frame cycle is two steps, giving frames per tile.
4. Writes assets/heroes/pl01/<anim>.png: 9 frames of 48x48 in a row, one row per
   facing: SW, SE, NW, NE (CreatureArtDef.rows).

2026-11-17: eight facings. The four screen directions drawn on 2026-11-17 (south,
east, north, west) are rows 5-8, and the walk stride is measured per facing along
the way it walks on screen (CreatureArtDef.run_px_per_frame).

2026-11-21: ability animations (NEW_ANIMS: earth_root, earth_hold, earth_punch, fire_punch,
fire_kick, water_heal, water_whip, air_palm, air_gust, stone_shatter), all eight facings,
named <who>+<slug>[@<facing>]_2026-11-21_<n>.png (no facing = south-east). Each one's
feet are measured on its own first frame in each facing (the soles, as for idle) and
the row shifted by whole pixels onto FEET. stone_shatter is the stone-armoured body
(PL-01-3) standing on a dirt mound: everything below its feet line (its lowest pixel
that isn't dirt) is cut, and dirt-coloured pixels just above it, before measuring.
PL-01-1+stone-skin-in-a-wide-rooted-stance-grey- is not used (no stone appears).

Run from the project root: python3 tools/once/make_hero_sheets.py
"""
import glob
import os
import subprocess

from PIL import Image

F = 48
FEET = (24, 38)  # the common feet point every facing is shifted onto
FACINGS = ["south-west", "south-east", "north-west", "north-east",
           "south", "east", "north", "west"]  # sheet rows (CreatureArtDef.rows)
ROWS = ["sw", "se", "nw", "ne", "s", "e", "n", "w"]
NEW = {"south", "east", "north", "west"}  # drawn 2026-11-17
OUT = "assets/heroes/pl01"
DST = "art/heroes"

# game animation -> (art folder, character, art animation, south-east file stem)
ANIMS = {
    "idle": ("PL-01", "PL-01-1", "idle", "2026-11-15"),
    "run": ("PL-01", "PL-01-1", "walk", "2026-11-15"),
    "cast": ("PL-01", "PL-01-1", "cast", "2026-11-15"),
    "hit": ("PL-01", "PL-01-1", "getting-hit", "2026-11-15"),
    "death": ("PL-01", "PL-01-1", "death", "2026-11-15_take1"),
    "downed": ("PL-01", "PL-01-1", "downed", "2026-11-15"),
    "revived": ("PL-01", "PL-01-1", "revived", "2026-11-15"),
    "sword_slash": ("PL-02", "PL-02-1", "sword-slash", "2026-11-16"),
    "sword_lunge": ("PL-02", "PL-02-1", "sword-lunge", "2026-11-16"),
    "bow_quick_shot": ("PL-02", "PL-02-2", "quick-bow-shot", "2026-11-16"),
    "bow_aimed_shot": ("PL-02", "PL-02-2", "aimed-bow-shot", "2026-11-16"),
}


# 2026-11-21: game animation -> (character, art slug); art/PL-01/, every facing.
NEW_ANIMS = {
    "earth_root": ("PL-01-1", "earthbending-root-drops-into-a-very-wide"),
    "earth_hold": ("PL-01-1", "earthbending-hold-keeps-a-deep-wide-hors"),
    "earth_punch": ("PL-01-1", "earthbending-punch-from-a-wide-rooted-ho"),
    "fire_punch": ("PL-01-1", "firebending-punch-very-fast-straight-jab"),
    "fire_kick": ("PL-01-1", "firebending-kick-fast-roundhouse-kick-at"),
    "water_heal": ("PL-01-1", "waterbending-heal-one-hand-sweeps-low-an"),
    "water_whip": ("PL-01-1", "waterbending-whip-quick-pull-back-of-one"),
    "air_palm": ("PL-01-1", "airbending-palm-light-step-forward-thrus"),
    "air_gust": ("PL-01-1", "airbending-gust-winds-both-arms-to-one-s"),
    "stone_shatter": ("PL-01-3", "stone-armour-cracks-all-over-and-falls-o"),
}
NEW_DATE = "2026-11-21"
MOUND = {"stone_shatter"}  # drawn standing on a dirt mound


def new_frame_paths(who, slug, facing):
    at = "" if facing == "south-east" else f"@{facing}"
    paths = [f"{DST}/PL-01/{who}+{slug}{at}_{NEW_DATE}_{i}.png" for i in range(1, 10)]
    for p in paths:
        if not os.path.exists(p):
            raise SystemExit(f"{p} is missing")
    return paths


def is_dirt(c):
    """The mound's brown earth (not the armour's grey, olive or glowing orange)."""
    r, g, b, a = c
    return a > 128 and r < 190 and r > g + 18 and g > b + 4 and r - b > 40


def is_outline(c):
    return c[3] > 128 and max(c[:3]) < 56


def mound_palette(img, line):
    """The mound's own colours: the ones below the soles (`line`) that never appear in
    the upper body (rows 6-28), outline black aside (the boots share it)."""
    px = img.load()
    body = {px[x, y] for y in range(6, 29) for x in range(F) if px[x, y][3] > 128}
    below = {px[x, y] for y in range(line + 1, F) for x in range(F) if px[x, y][3] > 128}
    return {c for c in below - body if not is_outline(c)}


BODY_HEIGHT = 32  # PL-01-1, head to soles; the stone-armoured body is drawn as tall


def feet_line(img):
    """The soles' row on the stone-armoured body: its top row + BODY_HEIGHT - 1 (the
    boots stand inside the mound, so no colour test finds them reliably)."""
    px = img.load()
    top = min(y for y in range(F) for x in range(F) if px[x, y][3] > 128)
    return top + BODY_HEIGHT - 1


def leg_columns(img, line):
    """The legs' columns just above the soles: the non-outline pixels in rows
    line-5..line-2 of the middle (x 10-38)."""
    px = img.load()
    xs = [x for y in range(line - 5, line - 1) for x in range(10, 39)
          if px[x, y][3] > 128 and not is_outline(px[x, y])]
    return (min(xs), max(xs)) if xs else (10, 38)


def mound_feet(img, line):
    """The feet point of the stone-armoured body: midway across its legs, on the soles."""
    lo, hi = leg_columns(img, line)
    return ((lo + hi) / 2, float(line))


def cut_mound(img, line, palette):
    """Removes the dirt mound: everything below the feet line `line`, and the mound's
    own colours `palette` from row 26 down, and in the 3 rows above the soles every
    colour found under them (and dirt brown); then outline
    pixels left touching nothing opaque but outline."""
    px = img.load()
    # Every colour under the soles, black aside: the rim just above the soles goes too.
    under = {px[x, y] for y in range(line + 1, F) for x in range(F)
             if px[x, y][3] > 128 and not is_outline(px[x, y])}
    for y in range(F):
        for x in range(F):
            c = px[x, y]
            if y > line or (y >= 26 and c in palette) or (y >= line - 2 and (c in under or is_dirt(c))):
                px[x, y] = (0, 0, 0, 0)
    lo, hi = leg_columns(img, line)
    for y in range(line - 1, line + 1):  # scraps beside the feet on the soles' rows
        for x in range(F):
            if (x < lo - 1 or x > hi + 1) and px[x, y][3] > 128:
                px[x, y] = (0, 0, 0, 0)
    for _ in range(2):
        gone = []
        for y in range(26, line + 1):
            for x in range(F):
                if is_outline(px[x, y]):
                    near = [px[x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                            if 0 <= x + dx < F and 0 <= y + dy < F and (dx or dy)]
                    if not any(n[3] > 128 and not is_outline(n) for n in near):
                        gone.append((x, y))
        for q in gone:
            px[q] = (0, 0, 0, 0)
    return img


def frame_paths(folder, who, anim, se_stem, facing):
    """The 9 frame files of one animation in one facing (south-east has no facing
    in its name, except the weapon sets, which name it)."""
    base = f"{DST}/{folder}/{who}+{anim}"
    if facing in NEW:
        pattern = f"{base}_{facing}_2026-11-17_[1-9].png"
    elif facing == "south-east" and folder == "PL-01":
        pattern = f"{base}_{se_stem}_[1-9].png"
    else:
        pattern = f"{base}_{facing}_2026-11-16_[1-9].png"
    paths = sorted(glob.glob(pattern), key=lambda p: int(p.rsplit("_", 1)[1].split(".")[0]))
    if len(paths) != 9:
        raise SystemExit(f"{pattern}: {len(paths)} frames, expected 9")
    return paths


def copy_from_drafts():
    files = subprocess.run(["git", "ls-tree", "-r", "--name-only", "origin/art-drafts"],
                           capture_output=True, text=True, check=True).stdout.split()
    wanted = []
    for folder, who, anim, se_stem in ANIMS.values():
        for f in files:
            name = f.rsplit("/", 1)[-1]
            if f.startswith(f"art/{folder}/{who}+{anim}_") and name.split("_")[-1][:-4].isdigit():
                if folder == "PL-01" and anim == "death" and "take" in name and "take1" not in name:
                    continue  # south-east death: take 1 of 4
                wanted.append(f)
    stills = ("art/PL-01/PL-01-1_no-bracelets_", "art/PL-02/PL-02-1_take1_", "art/PL-02/PL-02-2_take1_")
    wanted += ["approved/PL-01-1.png"] + [f for f in files if f.startswith(stills)
                                          and f.endswith(".png") and "8dir" not in f]
    # 2026-11-21: the ability sets (every facing, frames only), and PL-01-3's stills.
    for who, slug in NEW_ANIMS.values():
        wanted += [f for f in files if f.startswith(f"art/PL-01/{who}+{slug}")
                   and f.rsplit("_", 1)[-1][:-4].isdigit() and NEW_DATE in f]
    wanted += [f for f in files if f.startswith("art/PL-01/PL-01-3") and "+" not in f.split("/")[-1]
               or f.startswith("art/PL-01/PL-01-3+8dir")]
    copied = 0
    for f in sorted(set(wanted)):
        dst = f"{DST}/{f[len('art/'):]}" if f.startswith("art/") else f"{DST}/PL-01/{f.rsplit('/', 1)[-1]}"
        if os.path.exists(dst):
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        data = subprocess.run(["git", "show", f"origin/art-drafts:{f}"], capture_output=True, check=True).stdout
        with open(dst, "wb") as out:
            out.write(data)
        copied += 1
    print(f"copied {copied} files from art-drafts ({len(set(wanted))} wanted)")


def soles(img):
    """The two feet: the two largest blobs within 4 rows of the lowest row a sole
    reaches, each as (x of the middle of its bottom row, that row). A sole is at
    least 3 px wide; thinner tips (a scabbard or a bow hanging below the feet) are
    ignored."""
    px = img.load()
    pts = {(x, y) for y in range(F) for x in range(F) if px[x, y][3] > 128}

    def wide(y):  # the row has a run of 3+ opaque pixels
        run = 0
        for x in range(F):
            run = run + 1 if (x, y) in pts else 0
            if run >= 3:
                return True
        return False

    bottom = max(y for y in range(F) if wide(y))
    low = {(x, y) for x, y in pts if bottom - 4 <= y <= bottom}
    seen, blobs = set(), []
    for p in sorted(low):
        if p in seen:
            continue
        stack, blob = [p], []
        seen.add(p)
        while stack:
            q = stack.pop()
            blob.append(q)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (q[0] + dx, q[1] + dy)
                    if n in low and n not in seen:
                        seen.add(n)
                        stack.append(n)
        blobs.append(blob)
    blobs.sort(key=len, reverse=True)
    out = []
    for blob in blobs[:2]:
        sole = max(y for _, y in blob)
        xs = [x for x, y in blob if y == sole]
        out.append(((min(xs) + max(xs)) / 2, sole))
    return out


def feet_point(img):
    s = soles(img)
    if len(s) == 1:  # feet together
        return s[0]
    return ((s[0][0] + s[1][0]) / 2, (s[0][1] + s[1][1]) / 2)


def best_overlay(base, other, reach=6):
    """The (dx, dy) moving `other` onto `base` that overlaps their opaque pixels
    most (share of base's pixels covered)."""
    a = base.load()
    b = other.load()
    mine = [(x, y) for y in range(F) for x in range(F) if a[x, y][3] > 128]
    theirs = {(x, y) for y in range(F) for x in range(F) if b[x, y][3] > 128}
    best = (0, 0, -1.0)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            hit = sum(1 for x, y in mine if (x - dx, y - dy) in theirs)
            score = hit / len(mine)
            if score > best[2] or (score == best[2] and abs(dx) + abs(dy) < abs(best[0]) + abs(best[1])):
                best = (dx, dy, score)
    return best


def main():
    copy_from_drafts()
    os.makedirs(OUT, exist_ok=True)
    # Feet per facing, from the plain body's first idle frame.
    shifts = {}
    print("feet point (first idle frame), shift onto", FEET)
    for facing in FACINGS:
        img = Image.open(frame_paths(*ANIMS["idle"], facing)[0]).convert("RGBA")
        fx, fy = feet_point(img)
        shifts[facing] = (round(FEET[0] - fx), round(FEET[1] - fy))
        print(f"  {facing:11s} feet ({fx:5.2f}, {fy:5.2f})  shift {shifts[facing]}")
    # The weapon sets are other characters' bodies: overlay their stills on PL-01-1's.
    weapon_shifts = {}
    for who in ("PL-02-1", "PL-02-2"):
        weapon_shifts[who] = {}
        for facing in FACINGS:
            base = Image.open(f"{DST}/PL-01/PL-01-1_no-bracelets_{facing}.png").convert("RGBA")
            other = Image.open(f"{DST}/PL-02/{who}_take1_{facing}.png").convert("RGBA")
            ox, oy, score = best_overlay(base, other)
            sx, sy = shifts[facing]
            weapon_shifts[who][facing] = (sx + ox, sy + oy)
            print(f"  {who} {facing:11s} lines up with PL-01-1 moved by ({ox}, {oy}) "
                  f"({score:.0%} of the body overlaps)  shift {weapon_shifts[who][facing]}")
    # Walk stride, per facing, along the way it walks on screen: east/west across,
    # north/south up and down, the diagonals (grid axes, 16 px across and 8 down per
    # tile) along their slope. A 9-frame cycle is two steps.
    px_per_frame = {}
    for facing, row in zip(FACINGS, ROWS):
        steps = []
        for p in frame_paths(*ANIMS["run"], facing):
            s = soles(Image.open(p).convert("RGBA"))
            if len(s) == 2:
                dx, dy = abs(s[0][0] - s[1][0]), abs(s[0][1] - s[1][1])
                steps.append(dy if facing in ("north", "south") else
                             dx if facing in ("east", "west") else dx * (16 ** 2 + 8 ** 2) ** 0.5 / 16)
        step = max(steps)
        px_per_frame[row] = round(2 * step / 9, 3)
        print(f"  walk {facing:11s} widest step {step:.1f} art px: {px_per_frame[row]} px per frame")
    print("run_px_per_frame =", px_per_frame)
    # Sheets.
    for name, (folder, who, anim, se_stem) in ANIMS.items():
        table = weapon_shifts.get(who, shifts)
        sheet = Image.new("RGBA", (9 * F, len(FACINGS) * F))
        for row, facing in enumerate(FACINGS):
            dx, dy = table[facing]
            for i, path in enumerate(frame_paths(folder, who, anim, se_stem, facing)):
                img = Image.open(path).convert("RGBA")
                if img.size != (F, F):
                    raise SystemExit(f"{path}: {img.size}, expected {F}x{F}")
                cell = Image.new("RGBA", (F, F))
                cell.alpha_composite(img, (dx, dy)) if dx >= 0 and dy >= 0 else cell.paste(img, (dx, dy), img)
                sheet.alpha_composite(cell, (i * F, row * F))
        sheet.save(f"{OUT}/{name}.png")
        print(f"wrote {OUT}/{name}.png")
    # 2026-11-21: the ability animations, each measured on its own first frame.
    print("ability animations: feet on the first frame, shift onto", FEET)
    for name, (who, slug) in NEW_ANIMS.items():
        sheet = Image.new("RGBA", (9 * F, len(FACINGS) * F))
        notes = []
        for row, facing in enumerate(FACINGS):
            frames = [Image.open(p).convert("RGBA") for p in new_frame_paths(who, slug, facing)]
            for p, img in zip(new_frame_paths(who, slug, facing), frames):
                if img.size != (F, F):
                    raise SystemExit(f"{p}: {img.size}, expected {F}x{F}")
            if name in MOUND:  # the feet line and the rim from the first frame, for all
                line = feet_line(frames[0])
                palette = set()
                for img in frames:
                    palette |= mound_palette(img, line)
                frames = [cut_mound(img, line, palette) for img in frames]
                fx, fy = mound_feet(frames[0], line)
            else:
                fx, fy = feet_point(frames[0])
            dx, dy = round(FEET[0] - fx), round(FEET[1] - fy)
            notes.append(f"{ROWS[row]} ({fx:.1f}, {fy:.1f}) -> ({dx}, {dy})")
            for i, img in enumerate(frames):
                cell = Image.new("RGBA", (F, F))
                cell.paste(img, (dx, dy), img)
                sheet.alpha_composite(cell, (i * F, row * F))
        sheet.save(f"{OUT}/{name}.png")
        print(f"  {name:14s} " + "; ".join(notes))


if __name__ == "__main__":
    main()
