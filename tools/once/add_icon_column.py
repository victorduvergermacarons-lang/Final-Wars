"""One-off (2026-11-22, icons): adds an Icon column (after the last one) to the Abilities tab of
design/Ability_Tree.xlsx, patched as XML like ability_animations_sheet.py, so the
sheet's formulas keep their cached results. Each Fire, Earth, Water and Air ability
gets assets/icons/abilities/<ID>.png when that file exists; Sword, Bow and Hammer stay
empty (no icons yet). Header styled like the column before it. Then re-import:

    python3 tools/once/add_icon_column.py
    godot --headless --path . -s res://tools/import_ability_tree.gd
"""
import os
import re
import shutil
import tempfile
import zipfile
from xml.sax.saxutils import escape

SHEET = "design/Ability_Tree.xlsx"
ABILITIES = "xl/worksheets/sheet1.xml"


def col_letter(n):
    s = ""
    while n:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


def col_number(ref):
    n = 0
    for ch in ref:
        n = n * 26 + ord(ch) - 64
    return n


def main():
    z = zipfile.ZipFile(SHEET)
    files = {n: z.read(n) for n in z.namelist()}
    z.close()
    shared = re.findall(r"<si>(.*?)</si>", files.get("xl/sharedStrings.xml", b"").decode(), re.S)
    texts = ["".join(re.findall(r"<t[^>]*>(.*?)</t>", s, re.S)) for s in shared]
    xml = files[ABILITIES].decode()
    header = re.search(r'<row r="1".*?</row>', xml, re.S).group(0)
    last = max(col_number(c) for c in re.findall(r'<c r="([A-Z]+)1"', header))
    if ">Icon<" in header:
        raise SystemExit("the Icon column is already there")
    COL = col_letter(last + 1)
    PREV = col_letter(last)

    def cell_text(c):
        v = re.search(r"<v>(.*?)</v>", c)
        if 't="s"' in c and v:
            return texts[int(v.group(1))]
        t = re.search(r"<t[^>]*>(.*?)</t>", c, re.S)
        return t.group(1) if t else (v.group(1) if v else "")

    done = 0
    for row in re.findall(r'<row r="\d+".*?</row>', xml, re.S):
        n = re.search(r'<row r="(\d+)"', row).group(1)
        if n == "1":
            style = re.search(rf'<c r="{PREV}1"[^>]*?s="(\d+)"', row)
            st = f' s="{style.group(1)}"' if style else ""
            value = "Icon"
        else:
            first = re.search(rf'<c r="A{n}"[^>]*?(?:/>|>.*?</c>)', row, re.S)
            rid = cell_text(first.group(0)).strip() if first else ""
            path = f"assets/icons/abilities/{rid}.png"
            if not rid or not os.path.exists(path):
                continue
            style = re.search(rf'<c r="{PREV}{n}"[^>]*?s="(\d+)"', row)
            st = f' s="{style.group(1)}"' if style else ""
            value = path
            done += 1
        cell = f'<c r="{COL}{n}"{st} t="inlineStr"><is><t>{escape(value)}</t></is></c>'
        xml = xml.replace(row, row.replace("</row>", cell + "</row>"), 1)
    xml = re.sub(r'<dimension ref="A1:[A-Z]+(\d+)"/>', rf'<dimension ref="A1:{COL}\1"/>', xml)
    xml = xml.replace("</cols>", f'<col min="{last + 1}" max="{last + 1}" width="34" customWidth="1"/></cols>', 1)
    files[ABILITIES] = xml.encode()
    tmp = tempfile.mktemp(suffix=".xlsx")
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as out:
        for name, data in files.items():
            out.writestr(name, data)
    shutil.move(tmp, SHEET)
    print(f"Icon column added; {done} abilities have an icon")


if __name__ == "__main__":
    main()
