"""Copies the game's icons from the art bot's draft branch into assets/icons/.

    git fetch origin art-drafts
    python3 tools/pull_icons.py            # every icon
    python3 tools/pull_icons.py F07 sword  # only these IDs (ability IDs or item IDs)

What it does:
1. `git checkout origin/art-drafts -- icons/abilities icons/items` (only the game files;
   icons/previews, sheets and sliced stay on art-drafts), then moves them to
   assets/icons/abilities/<ID>.png and assets/icons/items/<item_id>.png and removes the
   icons/ folder it checked out (it isn't part of the game).
2. Writes each icon's .import file with the pixel-art settings: lossless, no mipmaps,
   no fix-alpha-border (Godot has no per-folder import presets, so every file carries
   them; tests/unit/test_icons.gd checks they all do). Nearest filtering is the
   project's default (rendering/textures/canvas_textures/default_texture_filter).
3. Draws assets/icons/placeholder.png (the shared icon for anything missing) if absent.

Then let Godot import them: godot --headless --path . --import
"""
import os
import shutil
import subprocess
import sys

DEST = "assets/icons"
KINDS = ("abilities", "items")
PARAMS = """[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(png):
    """Keeps Godot's [remap]/[deps] if the file has them; always rewrites [params]."""
    path = png + ".import"
    head = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
    if os.path.exists(path):
        text = open(path).read()
        head = text.split("[params]")[0]
    with open(path, "w") as f:
        f.write(head + PARAMS)


def placeholder(path):
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (36, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 31, 31], fill=(70, 62, 78, 255), outline=(20, 16, 24, 255))
    d.rectangle([5, 5, 30, 30], outline=(150, 140, 160, 255))
    # A pixel question mark.
    for x, y in [(15, 10), (16, 10), (17, 10), (18, 10), (19, 11), (20, 12), (20, 13), (19, 14),
                 (18, 15), (17, 16), (17, 17), (17, 18), (17, 22), (17, 23)]:
        d.rectangle([x, y, x, y], fill=(235, 225, 120, 255))
    d.point([(14, 11), (14, 12)], fill=(235, 225, 120, 255))
    img.save(path)


def main(only):
    subprocess.run(["git", "checkout", "origin/art-drafts", "--", "icons/abilities", "icons/items"], check=True)
    subprocess.run(["git", "reset", "-q", "--", "icons"], check=True)
    copied = 0
    for kind in KINDS:
        os.makedirs(f"{DEST}/{kind}", exist_ok=True)
        for name in sorted(os.listdir(f"icons/{kind}")):
            if not name.endswith(".png") or (only and name[:-4] not in only):
                continue
            dst = f"{DEST}/{kind}/{name}"
            shutil.copyfile(f"icons/{kind}/{name}", dst)
            write_import(dst)
            copied += 1
    shutil.rmtree("icons")
    ph = f"{DEST}/placeholder.png"
    if not os.path.exists(ph):
        placeholder(ph)
    write_import(ph)
    print(f"copied {copied} icons into {DEST}/ (import with: godot --headless --path . --import)")


if __name__ == "__main__":
    main(set(sys.argv[1:]))
