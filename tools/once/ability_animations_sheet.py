"""One-off (2026-11-21, ability animations): timing and movement changes in
design/Ability_Tree.xlsx, Abilities tab, patched as XML so the sheet's formulas keep
their cached results (openpyxl would drop them; the importer reads them).

- F01 Fire Punch: instant. No timing bar (it was 1 s, tap 0.7-1.0, crit 0.9-1.0).
- W02 Water Whip: the hold window starts at 0.45 s (was 0.75 s); it still ends at 2.75 s.
- E01 Rock Throw: two presses. The first starts a 3 s bar while the rock rises and
  waits; the second (right-click or Space, as for every bar) throws it. No press:
  it throws itself when the bar ends. Tap 0.6-2.6, crit 0.9-1.1 (was 1.6 s, tap
  1.1-1.5, crit 1.25-1.35). Cast Move Speed 0: the hero can't move while the rock is up.

Then re-import: godot --headless --path . -s res://tools/import_ability_tree.gd

    python3 tools/once/ability_animations_sheet.py
"""
import re
import shutil
import tempfile
import zipfile
from xml.sax.saxutils import escape

SHEET = "design/Ability_Tree.xlsx"
ABILITIES = "xl/worksheets/sheet1.xml"

CHANGES = {
    "F01": {"Timing Status": "Manual", "Timing Bar (s)": "none", "Timing Zones": "",
            "Timing Notes": "Instant since 2026-11-21: no bar; damage lands as the key is pressed "
                            "(was 1 s, Tap 0.7–1.0; Crit 0.9–1.0)."},
    "W02": {"Timing Zones": "Hold 0.45–2.75",
            "Timing Notes": "Designer's bar: the hold starts at 0.45 s (was 0.75 s, 2026-11-21) and "
                            "ends 0.25 s before the bar."},
    "E01": {"Timing Status": "Generated (AI, not yet confirmed)", "Timing Bar (s)": "3",
            "Timing Zones": "Tap 0.6–2.6; Crit 0.9–1.1",
            "Timing Notes": "Two presses (2026-11-21): the first raises the rock, the second (right-click "
                            "or Space) throws it; no press, it throws itself at the bar's end. "
                            "Was 1.6 s, Tap 1.1–1.5; Crit 1.25–1.35.",
            "Cast Move Speed (%)": "0"},
}


def col_letter(n):
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def main():
    z = zipfile.ZipFile(SHEET)
    files = {n: z.read(n) for n in z.namelist()}
    z.close()
    shared = re.findall(r"<si>(.*?)</si>", files["xl/sharedStrings.xml"].decode(), re.S)
    texts = ["".join(re.findall(r"<t[^>]*>(.*?)</t>", s, re.S)) for s in shared]
    xml = files[ABILITIES].decode()

    def cell_text(c):
        v = re.search(r"<v>(.*?)</v>", c)
        if 't="s"' in c and v:
            return texts[int(v.group(1))]
        t = re.search(r"<t[^>]*>(.*?)</t>", c, re.S)
        return t.group(1) if t else (v.group(1) if v else "")

    header = re.search(r'<row r="1".*?</row>', xml, re.S).group(0)
    cols = {}
    for c in re.findall(r"<c [^>]*?(?:/>|>.*?</c>)", header, re.S):
        ref = re.search(r'r="([A-Z]+)1"', c).group(1)
        cols[cell_text(c).replace("&amp;", "&")] = ref
    for name in {k for ch in CHANGES.values() for k in ch}:
        if name not in cols:
            raise SystemExit(f"no column '{name}' in the Abilities tab")

    def set_cell(row_xml, rownum, ref, value):
        cell_ref = f"{ref}{rownum}"
        m = re.search(rf'<c r="{cell_ref}"[^>]*?(?:/>|>.*?</c>)', row_xml, re.S)
        style = re.search(r's="(\d+)"', m.group(0)).group(1) if m and 's="' in m.group(0) else None
        st = f' s="{style}"' if style else ""
        if value == "":
            new = f'<c r="{cell_ref}"{st}/>'
        elif re.fullmatch(r"-?\d+(\.\d+)?", value):
            new = f'<c r="{cell_ref}"{st}><v>{value}</v></c>'
        else:
            new = f'<c r="{cell_ref}"{st} t="inlineStr"><is><t>{escape(value)}</t></is></c>'
        if m:
            return row_xml.replace(m.group(0), new)
        # Insert in column order.
        def colnum(r):
            n = 0
            for ch in r:
                n = n * 26 + ord(ch) - 64
            return n
        cells = list(re.finditer(r'<c r="([A-Z]+)\d+"[^>]*?(?:/>|>.*?</c>)', row_xml, re.S))
        for c in cells:
            if colnum(c.group(1)) > colnum(ref):
                return row_xml[:c.start()] + new + row_xml[c.start():]
        return row_xml.replace("</row>", new + "</row>")

    done = set()
    for row in re.findall(r'<row r="\d+".*?</row>', xml, re.S):
        rownum = re.search(r'<row r="(\d+)"', row).group(1)
        first = re.search(rf'<c r="A{rownum}"[^>]*?(?:/>|>.*?</c>)', row, re.S)
        if not first:
            continue
        rid = cell_text(first.group(0)).strip()
        if rid in CHANGES:
            new_row = row
            for name, value in CHANGES[rid].items():
                new_row = set_cell(new_row, rownum, cols[name], value)
            xml = xml.replace(row, new_row)
            done.add(rid)
    if done != set(CHANGES):
        raise SystemExit(f"rows not found: {set(CHANGES) - done}")
    files[ABILITIES] = xml.encode()
    tmp = tempfile.mktemp(suffix=".xlsx")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as out:
        for n, data in files.items():
            out.writestr(n, data)
    shutil.move(tmp, SHEET)
    print("patched", ", ".join(sorted(done)))


if __name__ == "__main__":
    main()
