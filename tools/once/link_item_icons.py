"""One-off (2026-11-22, icons): points every item file in content/items/ at its icon,
assets/icons/items/<id>.png, when that file exists (an ext_resource with the icon's
uid, and `icon = ExtResource(...)` in [resource]). Items without art are left alone.
Run after tools/pull_icons.py and a Godot import (the uids come from the .import files).

    python3 tools/once/link_item_icons.py
"""
import glob
import os
import re

linked, skipped = 0, []
for path in sorted(glob.glob("content/items/*.tres")):
    text = open(path).read()
    m = re.search(r'^id = &"([^"]+)"', text, re.M)
    item_id = m.group(1) if m else os.path.basename(path)[:-5]
    png = f"assets/icons/items/{item_id}.png"
    if not os.path.exists(png):
        skipped.append(item_id)
        continue
    if "icon = ExtResource(" in text:
        continue
    uid = re.search(r'^uid="([^"]+)"', open(png + ".import").read(), re.M)
    uid_attr = f' uid="{uid.group(1)}"' if uid else ""
    ext = f'[ext_resource type="Texture2D"{uid_attr} path="res://{png}" id="icon_tex"]\n'
    # After the last ext_resource line (or the header).
    lines = text.split("\n")
    last = max((i for i, l in enumerate(lines) if l.startswith("[ext_resource")), default=0)
    lines.insert(last + 1, ext.rstrip("\n"))
    text = "\n".join(lines)
    text = re.sub(r"load_steps=(\d+)", lambda k: f"load_steps={int(k.group(1)) + 1}", text, count=1)
    head, sep, body = text.partition("\n[resource]\n")
    body = re.sub(r'^(display_name = .*)$', r'\1\nicon = ExtResource("icon_tex")', body, count=1, flags=re.M)
    if 'icon = ExtResource("icon_tex")' not in body:
        body = 'icon = ExtResource("icon_tex")\n' + body
    open(path, "w").write(head + sep + body)
    linked += 1
print(f"linked {linked} item files; no art: {', '.join(skipped)}")
