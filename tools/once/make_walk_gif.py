"""Joins tests/visual/hero_walk_shots.tscn's crops into one GIF: the eight
directions side by side (e, se, s, sw on top; w, nw, n, ne below), at 30 fps.
Usage: python3 tools/once/make_walk_gif.py <shots dir>"""
import glob
import sys

from PIL import Image

d = sys.argv[1]
dirs = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
frames = {k: sorted(glob.glob(f"{d}/walk_{k}_*.png")) for k in dirs}
n = min(len(v) for v in frames.values())
out = []
for i in range(n):
    sheet = Image.new("RGB", (4 * 220, 2 * 220))
    for j, k in enumerate(dirs):
        sheet.paste(Image.open(frames[k][i]).convert("RGB"), ((j % 4) * 220, (j // 4) * 220))
    out.append(sheet)
out[0].save(f"{d}/walk.gif", save_all=True, append_images=out[1:], duration=33, loop=0)
print(f"{d}/walk.gif: {n} frames")
