"""Ability rebalance (user request, 2026-11-17), in design/Ability_Tree.xlsx:
- every ranged ability (Targeted beyond adjacent, Projectile, Lob, Circle, Line and
  ground Tiles with a range) reaches 2 tiles further: Hitbox Range (Z) + 2, and the
  range written in its Effect (L) and Targeting Details (N) text;
- Water's healing abilities scale with 0.45 Magic Atk and 0.55 Phys Def;
- Air scales with Phys Atk instead of Magic Atk; its control and defense abilities
  with 0.6 Phys Atk and 0.4 Magic Def.
Patches the sheet's XML (openpyxl would drop the cached results of its formulas,
which the importer reads); refuses to touch a cell holding a formula.

Run from the project root: python3 tools/once/ability_rebalance.py
Then re-import: godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import re
import shutil
import zipfile

PATH = "design/Ability_Tree.xlsx"
RANGED = {"Targeted", "Projectile", "Lob", "Circle", "Line", "Tiles"}
WATER_HEALS = {"W01", "W05", "W10", "W17"}
WATER_HEAL_SCALING = "Water Mastery, 0.45 Magic Atk, 0.55 Phys Def"
AIR_CONTROL = {"A02", "A04", "A07", "A11", "A12", "A17", "A18"}  # interrupts, snares, silences, shields, roots

zin = zipfile.ZipFile(PATH)
sheet = zin.read("xl/worksheets/sheet1.xml").decode("utf-8")
shared = [re.sub(r"<[^>]+>", "", x) for x in
          re.findall(r"<si>(.*?)</si>", zin.read("xl/sharedStrings.xml").decode("utf-8"), re.S)]


def unescape(t):
    return t.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&apos;", "'").replace("&amp;", "&")


def cell_text(row, col):
    m = re.search(r'<c r="%s%d"([^>]*?)(?:/>|>(.*?)</c>)' % (col, row), sheet, re.S)
    if not m or not m.group(2):
        return ""
    attrs, inner = m.group(1), m.group(2)
    if "inlineStr" in attrs:
        return unescape("".join(re.findall(r"<t[^>]*>(.*?)</t>", inner, re.S)))
    v = re.search(r"<v>(.*?)</v>", inner)
    v = v.group(1) if v else ""
    return unescape(shared[int(v)]) if 't="s"' in attrs else v


def has_formula(row, col):
    m = re.search(r'<c r="%s%d"[^>]*?>(.*?)</c>' % (col, row), sheet, re.S)
    return bool(m and "<f>" in m.group(1))


def set_cell(row, col, value):
    global sheet
    assert not has_formula(row, col), "%s%d holds a formula" % (col, row)
    pat = re.compile(r'<c r="%s%d"( s="\d+")?[^>]*?(?:/>|>.*?</c>)' % (col, row), re.S)
    m = pat.search(sheet)
    assert m, "%s%d missing" % (col, row)
    style = m.group(1) or ""
    if isinstance(value, (int, float)):
        new = '<c r="%s%d"%s><v>%s</v></c>' % (col, row, style, value)
    else:
        text = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        new = '<c r="%s%d"%s t="inlineStr"><is><t>%s</t></is></c>' % (col, row, style, text)
    sheet = sheet[:m.start()] + new + sheet[m.end():]


def plus_two(text, shape, where):
    """The range written in the text, two tiles further: the first "within N",
    "range N" or "up to N tiles away" in the cell (later numbers are area sizes,
    "within 1 of the target"), or a Line's length ("3-tile line"). Counts, heights
    and durations ("up to 3 enemies", "up to 3s") aren't ranges and stay."""
    if where in SKIP_TEXT:
        return text
    def bump(m):
        return "%s%d%s" % (m.group(1), int(m.group(2)) + 2, m.group(3))
    pattern = r"([Ww]ithin |[Rr]ange |up to )(\d+)((?: tiles? away)|(?=[ .;,]|$)(?! of)(?: tiles?)?)"
    out = text
    m = re.search(pattern, out)
    if m and not (m.group(1) == "up to " and "away" not in m.group(3)):
        out = out[:m.start()] + bump(m) + out[m.end():]
    if shape == "Line":
        out = re.sub(r"()(\d+)(-tile line)", bump, out, count=1)
    return out


# Cells whose first number isn't the cast range (Ricochet Arrow: the bounce reach).
SKIP_TEXT = {"B18 N", "A06 L"}  # Ricochet: bounce reach; Vortex: its pull area


changes = []
for r in range(2, 400):
    ability_id = cell_text(r, "A")
    if not re.fullmatch(r"[A-Z]\d\d", ability_id):
        continue
    shape = cell_text(r, "Y")
    rng = cell_text(r, "Z")
    if shape in RANGED and rng and float(rng) >= 1.5:
        new = float(rng) + 2
        set_cell(r, "Z", int(new) if new == int(new) else new)
        for col in ("L", "N"):
            old = cell_text(r, col)
            text = plus_two(old, shape, f"{ability_id} {col}")
            if text != old:
                set_cell(r, col, text)
                changes.append(f"{ability_id} {col}: {old!r} -> {text!r}")
        changes.append(f"{ability_id} range {rng} -> {new:g} ({shape})")
    scales = cell_text(r, "K")
    if ability_id in WATER_HEALS:
        set_cell(r, "K", WATER_HEAL_SCALING)
        changes.append(f"{ability_id} scales {scales!r} -> {WATER_HEAL_SCALING!r}")
    elif cell_text(r, "B") == "Air" and "Magic Atk" in scales:
        new = scales.replace("Magic Atk", "0.6 Phys Atk, 0.4 Magic Def" if ability_id in AIR_CONTROL else "Phys Atk")
        set_cell(r, "K", new)
        changes.append(f"{ability_id} scales {scales!r} -> {new!r}")

tmp = PATH + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename == "xl/worksheets/sheet1.xml":
            data = sheet.encode("utf-8")
        zout.writestr(info, data)
zin.close()
shutil.move(tmp, PATH)
print("\n".join(changes))
print(len(changes), "changes")
