"""Earth (Stone Guard) tanking abilities (user request, 2026-11-17).

Patches design/Ability_Tree.xlsx in place, editing its XML directly (openpyxl would
drop the cached results of the sheet's formulas, which the importer reads); only
plain cells change, so every formula (Mastery Required, the Tiers lookups) stays:
- Abilities tab, Effect (L), Cooldown (O) and Notes (T) of the Earth abilities built
  for tanking: Rock Throw, Stone Skin, Seismic Stomp, Boulder Shield, Rumbling Taunt,
  Earth Armor and Metalbending;
- Timing Status / Bar / Notes (U, V, X) of the newly built instants: "Generated", no
  bar, like the other instants (taunts, buffs, shields, pulls).

Run from the project root: python3 tools/once/earth_tanking.py
Then re-import: godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import re
import shutil
import zipfile

PATH = "design/Ability_Tree.xlsx"
GENERATED = "Generated (AI, not yet confirmed)"

# ID -> {column: text or number}
CHANGES = {
    "E01": {
        "L": "Hurl a rock, range 4. Generates 3x threat: the Stone Guard's ranged opener.",
        "T": "Threat x3.",
    },
    "E02": {
        "L": "Gain +20 Physical Defense for 10s.",
        "T": "Physical Defense raises all your threat while it lasts; lets Metalbending taunt.",
        "U": GENERATED, "V": "none", "X": "No bar: a self buff.",
    },
    "E04": {
        "L": "Taunt every enemy on the 8 tiles around you for 4s and hit them for light Physical damage.",
        "O": 8,
        "T": "Everyday pack grab. Taunt: top threat +10% and the enemy is forced onto you for 4s. "
             "Damage 70% of Rock Throw's, so you keep threat after the taunt.",
    },
    "E07": {
        "L": "Absorb shield on yourself for 12s; size scales with Earth Mastery and Physical Defense.",
        "U": GENERATED, "V": "none", "X": "No bar: a self shield.",
    },
    "E08": {
        "L": "Taunt all enemies within 2 tiles for 5s.",
        "O": 120,
        "T": "Emergency AoE taunt: top threat +10% and every enemy is forced onto you for 5s.",
        "U": GENERATED, "V": "none", "X": "No bar: a taunt.",
    },
    "E14": {
        "L": "Encase yourself in rock for 15s: +50 Physical Defense, steps 50% slower.",
        "T": "Physical Defense raises all your threat while it lasts; lets Metalbending taunt.",
        "U": GENERATED, "V": "none", "X": "No bar: a self buff.",
    },
    "E15": {
        "L": "Bend an enemy's armor: -20 Physical Defense for 8s and pull it 2 tiles toward you. "
             "With Stone Skin or Earth Armor up, also taunts it for 3s.",
        "T": "Single-target grab for tanks; without Stone Skin or Earth Armor it doesn't taunt, "
             "so a damage-dealing earthbender keeps it without pulling aggro.",
        "U": GENERATED, "V": "none", "X": "No bar: a pull.",
    },
}

zin = zipfile.ZipFile(PATH)
sheet = zin.read("xl/worksheets/sheet1.xml").decode("utf-8")
shared = [re.sub(r"<[^>]+>", "", x) for x in
          re.findall(r"<si>(.*?)</si>", zin.read("xl/sharedStrings.xml").decode("utf-8"), re.S)]


def cell_text(row: int, col: str) -> str:
    m = re.search(r'<c r="%s%d"([^>]*?)(?:/>|>(.*?)</c>)' % (col, row), sheet, re.S)
    if not m or not m.group(2):
        return ""
    attrs, inner = m.group(1), m.group(2)
    if "inlineStr" in attrs:
        return re.search(r"<t[^>]*>(.*?)</t>", inner).group(1)
    v = re.search(r"<v>(.*?)</v>", inner)
    v = v.group(1) if v else ""
    return shared[int(v)] if 't="s"' in attrs else v


def has_formula(row: int, col: str) -> bool:
    m = re.search(r'<c r="%s%d"[^>]*?>(.*?)</c>' % (col, row), sheet, re.S)
    return bool(m and "<f>" in m.group(1))


def set_cell(row: int, col: str, value) -> None:
    """Writes text (inline string) or a number into a plain cell, keeping its style;
    adds the cell, in column order, if the row has none there."""
    global sheet
    assert not has_formula(row, col), "%s%d holds a formula" % (col, row)
    pat = re.compile(r'<c r="%s%d"( s="\d+")?[^>]*?(?:/>|>.*?</c>)' % (col, row), re.S)
    m = pat.search(sheet)
    style = (m.group(1) or "") if m else ""
    if isinstance(value, (int, float)):
        new = '<c r="%s%d"%s><v>%s</v></c>' % (col, row, style, value)
    else:
        text = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        new = '<c r="%s%d"%s t="inlineStr"><is><t>%s</t></is></c>' % (col, row, style, text)
    if m:
        sheet = sheet[:m.start()] + new + sheet[m.end():]
        return
    # No cell yet: insert before the first cell of a later column in this row.
    row_m = re.search(r'<row r="%d"[^>]*>(.*?)</row>' % row, sheet, re.S)
    assert row_m, row

    def col_index(c: str) -> int:
        n = 0
        for ch in c:
            n = n * 26 + ord(ch) - 64
        return n

    insert_at = row_m.end(1)
    for c in re.finditer(r'<c r="([A-Z]+)%d"' % row, row_m.group(1)):
        if col_index(c.group(1)) > col_index(col):
            insert_at = row_m.start(1) + c.start()
            break
    sheet = sheet[:insert_at] + new + sheet[insert_at:]


rows = {}
for r in range(2, 400):
    if cell_text(r, "A") in CHANGES:
        rows[cell_text(r, "A")] = r
assert set(rows) == set(CHANGES), set(rows) ^ set(CHANGES)
for ability_id, cols in CHANGES.items():
    for col, value in cols.items():
        set_cell(rows[ability_id], col, value)

tmp = PATH + ".tmp"
with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
    for info in zin.infolist():
        data = zin.read(info.filename)
        if info.filename == "xl/worksheets/sheet1.xml":
            data = sheet.encode("utf-8")
        zout.writestr(info, data)
zin.close()
shutil.move(tmp, PATH)
print("patched", len(CHANGES), "Earth rows")
