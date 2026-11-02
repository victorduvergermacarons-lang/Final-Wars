"""One-off (free movement, phase 3): add the Hitbox columns to the Abilities tab of
design/Ability_Tree.xlsx and fill them for all 145 abilities from the tables in
docs/FREE_MOVEMENT_PLAN.md (section 6 for the 32 implemented abilities, Appendix B
for the rest). Adds a "Hitbox Rules" note to the Timing Rules tab.

    python3 tools/once/fill_hitbox_columns.py

Run once (it refuses a sheet that already has the columns); then edit the sheet
directly. The file is patched as XML so its formulas keep their results.
"""
import os
import re
import sys
import zipfile
from xml.sax.saxutils import escape
import openpyxl

SHEET = "design/Ability_Tree.xlsx"
PLAN = "docs/FREE_MOVEMENT_PLAN.md"
COLUMNS = ["Hitbox Shape", "Hitbox Range", "Hitbox Angle", "Hitbox Width", "Hitbox Radius",
           "Projectile Speed", "Projectile Size", "Pierce"]


def num(pat, s, default=None):
    m = re.search(pat, s)
    return float(m.group(1)) if m else default


def from_text(label, values):
    """(shape, range, angle, width, radius, speed, size, pierce) from a plan row."""
    text = label + " " + values
    low = text.lower()
    rng = num(r"range (\d+(?:\.\d+)?)", text)
    pierce = "pierce" in low
    out = {"shape": "", "range": None, "angle": None, "width": None, "radius": None,
           "speed": None, "size": None, "pierce": pierce}
    grid = re.search(r"(\d)\s*[x×]\s*(\d)", text)
    if "tiles (grid" in low or "terrain (grid)" in low or "zone (grid)" in low:
        out.update(shape="Tiles", range=rng or 3, radius=(int(grid.group(1)) - 1) // 2 if grid else 0)
    elif "self (no hitbox)" in low or label.strip().startswith("Self:") or label.strip() == "Self":
        out.update(shape="None")
    elif low.startswith("self circle"):
        out.update(shape="Self Circle", radius=num(r"r(?:adius)? (\d+(?:\.\d+)?)", text, 1.5))
    elif low.startswith("cone") or label.startswith("Arc"):
        out.update(shape="Cone", range=num(r"r(?:ange)? (\d+(?:\.\d+)?)", values, 1.6)
                   or num(r"range (\d+(?:\.\d+)?)", label, 1.4),
                   angle=num(r"(\d+)°", text, 120 if label.startswith("Arc") else 60))
        if label.startswith("Cone"):
            out["range"] = num(r"range (\d+(?:\.\d+)?)", label, out["range"])
            out["angle"] = num(r"Cone (\d+)°", label, out["angle"])
    elif low.startswith("rect") or low.startswith("line"):
        out.update(shape="Line", range=num(r"length (\d+(?:\.\d+)?)", text, 3),
                   width=num(r"width (\d+(?:\.\d+)?)", text, 0.8))
    elif low.startswith("projectile (lob)"):
        out.update(shape="Lob", range=rng or 4, radius=num(r"radius (\d+(?:\.\d+)?)", text, 0.5))
    elif low.startswith("projectile"):
        width = num(r"width (\d+(?:\.\d+)?)", text)
        out.update(shape="Projectile", range=rng or num(r"length (\d+(?:\.\d+)?)", text, 5),
                   speed=num(r"speed (\d+(?:\.\d+)?)", text, 6 if width else 14),
                   size=num(r"size (\d+(?:\.\d+)?)", text, width / 2 if width else 0.25))
    elif low.startswith("circle at point"):
        out.update(shape="Circle", range=rng or 5, radius=num(r"r(?:adius)? (\d+(?:\.\d+)?)", text, 1.5))
    elif low.startswith("dash"):
        out.update(shape="Dash", range=num(r"length (\d+(?:\.\d+)?)", text, 2),
                   width=num(r"width (\d+(?:\.\d+)?)", text, 0.6))
    elif low.startswith("leap"):
        out.update(shape="Leap", range=rng or 4, radius=num(r"r (\d+(?:\.\d+)?)", text, 1.5))
    elif low.startswith("blink"):
        out.update(shape="Blink", range=rng or 4)
    elif low.startswith("targeted"):
        melee = "melee" in low
        out.update(shape="Targeted", range=1.0 if melee else (rng or 3))
    else:
        sys.exit("No shape for: %r %r" % (label, values))
    return out


def plan_rows():
    rows = {}
    lines = open(PLAN, encoding="utf-8").read().splitlines()
    section = None
    for line in lines:
        if line.startswith("## 6."):
            section = 6
        elif line.startswith("## Appendix B"):
            section = "B"
        elif line.startswith("## "):
            section = None
        if section is None or not re.match(r"\| [A-Z]\d\d \|", line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if section == 6:
            # | ID | Ability | Today | New hitbox | Notes |
            new = cells[3].replace("**", "")
            label, _, values = new.partition(",")
            rows[cells[0]] = from_text(label.strip(), new)
        else:
            # | ID | Ability | Sheet targeting | Hitbox | Values |
            rows[cells[0]] = from_text(cells[3], cells[4])
    return rows


def col_name(n):
    out = ""
    while n:
        n, r = divmod(n - 1, 26)
        out = chr(65 + r) + out
    return out


def cell_xml(ref, v, style=None):
    st = ' s="%d"' % style if style is not None else ""
    if v is None or v == "":
        return ""
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return '<c r="%s"%s><v>%s</v></c>' % (ref, st, ("%g" % v))
    return '<c r="%s"%s t="inlineStr"><is><t>%s</t></is></c>' % (ref, st, escape(str(v)))


def append_cells(xml, row, cells):
    """Adds cells (already XML) at the end of row `row` (or a new row)."""
    m = re.search(r'<row r="%d"[^>]*?(/>|>)' % row, xml)
    if m is None:
        # A new row after the last one.
        i = xml.index("</sheetData>")
        return xml[:i] + '<row r="%d">%s</row>' % (row, cells) + xml[i:]
    if m.group(1) == "/>":
        return xml[:m.start()] + m.group(0)[:-2] + ">" + cells + "</row>" + xml[m.end():]
    end = xml.index("</row>", m.end())
    return xml[:end] + cells + xml[end:]


def main():
    # The sheet holds formulas whose cached results the game's reader uses, so
    # the file is patched as XML (openpyxl would drop those results).
    rows = plan_rows()
    book = openpyxl.load_workbook(SHEET, read_only=True)
    ws = book["Abilities"]
    header = [c.value for c in next(ws.iter_rows(min_row=1, max_row=1))]
    if "Hitbox Shape" in header:
        sys.exit("The sheet already has Hitbox columns; edit them there.")
    ids = {}
    for r, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
        if row[header.index("ID")]:
            ids[r] = row[header.index("ID")]
    timing_last = book["Timing Rules"].max_row if "Timing Rules" in book.sheetnames else 0
    book.close()
    first = len(header) + 1
    last = first + len(COLUMNS) - 1
    with zipfile.ZipFile(SHEET) as z:
        files = {n: z.read(n) for n in z.namelist()}
        infos = {i.filename: i for i in z.infolist()}
    xml = files["xl/worksheets/sheet1.xml"].decode("utf-8")
    style = int(re.search(r'<c r="A1" s="(\d+)"', xml).group(1))
    xml = append_cells(xml, 1, "".join(cell_xml(col_name(first + i) + "1", n, style) for i, n in enumerate(COLUMNS)))
    for r, aid in ids.items():
        if aid not in rows:
            sys.exit("No hitbox in the plan for " + aid)
        h = rows[aid]
        vals = [h["shape"], h["range"], h["angle"], h["width"], h["radius"], h["speed"], h["size"],
                "Yes" if h["pierce"] else ""]
        if h["shape"] == "Tiles" and h["radius"] is None:
            vals[4] = 0
        xml = append_cells(xml, r, "".join(cell_xml(col_name(first + i) + str(r), v) for i, v in enumerate(vals)))
    xml = re.sub(r'<dimension ref="A1:[A-Z]+(\d+)"/>', lambda m: '<dimension ref="A1:%s%s"/>' % (col_name(last), m.group(1)), xml)
    xml = re.sub(r'spans="1:%d"' % len(header), 'spans="1:%d"' % last, xml)
    xml = xml.replace("</cols>", '<col min="%d" max="%d" width="14" customWidth="1"/></cols>' % (first, last))
    files["xl/worksheets/sheet1.xml"] = xml.encode("utf-8")
    if timing_last:
        # The sheet named "Timing Rules" (find its file through the workbook).
        wb = files["xl/workbook.xml"].decode("utf-8")
        rid = re.search(r'<sheet name="Timing Rules"[^>]*r:id="(rId\d+)"', wb).group(1)
        rels = files["xl/_rels/workbook.xml.rels"].decode("utf-8")
        target = re.search(r'Id="%s"[^>]*Target="([^"]+)"' % rid, rels) or re.search(r'Target="([^"]+)"[^>]*Id="%s"' % rid, rels)
        path = "xl/" + target.group(1)
        tx = files[path].decode("utf-8")
        notes = [
            "Hitbox Rules (free movement)",
            "Hitbox Shape: None, Targeted, Cone, Line, Circle, Projectile, Lob, Self Circle, Dash, Leap, Blink, Tiles.",
            "Distances in tiles (continuous). Hitbox Range: Targeted edge to edge; Cone, Line and Dash length; Circle, Lob, Leap, Blink and Tiles how far the aim may be.",
            "Hitbox Angle: a cone's width in degrees. Hitbox Width: a line's or a dash's width. Hitbox Radius: a circle's radius (Tiles: tiles around the aimed one, 1 = 3x3).",
            "Projectile Speed (tiles/s) and Projectile Size (its radius). Pierce: Yes = hits everything on its path.",
            "Tiles stay on the grid (terrain, ground zones): they snap to the tile under the cursor.",
        ]
        for i, n in enumerate(notes):
            r = timing_last + 2 + i
            tx = append_cells(tx, r, cell_xml("A%d" % r, n))
        tx = re.sub(r'<dimension ref="A1:([A-Z]+)\d+"/>', lambda m: '<dimension ref="A1:%s%d"/>' % (m.group(1), timing_last + 1 + len(notes)), tx)
        files[path] = tx.encode("utf-8")
    tmp = SHEET + ".tmp"
    with zipfile.ZipFile(tmp, "w") as z:
        for n, data in files.items():
            z.writestr(infos[n], data, compress_type=zipfile.ZIP_DEFLATED)
    os.replace(tmp, SHEET)
    print("filled %d abilities (columns %s-%s)" % (len(ids), col_name(first), col_name(last)))


main()
