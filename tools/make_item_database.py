"""Writes design/Item_Database.xlsx from the JSON tools/item_database.tscn dumps:

    godot --headless --path . res://tools/item_database.tscn -- /tmp/items.json
    python3 tools/make_item_database.py /tmp/items.json

Tabs: Items (one row per item: kind, slot, rarity, stats, growth per level, price,
what it teaches, where it comes from), Sources (every way to get each item), Enemy
Loot (each enemy's table, with where it lives), About. Generated: edit the game's
content files, not this sheet, then regenerate it.
"""
import json
import sys

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

OUT = "design/Item_Database.xlsx"
RARITY_FILL = {"Common": "FFFFFF", "Uncommon": "D9EAD3", "Rare": "CFE2F3", "Epic": "D9D2E9"}
HEAD = Font(bold=True, color="FFFFFF")
HEAD_FILL = PatternFill("solid", fgColor="5F2C2C")


def header(ws, names):
    ws.append(names)
    for c in ws[1]:
        c.font = HEAD
        c.fill = HEAD_FILL
        c.alignment = Alignment(wrap_text=True, vertical="top")
    ws.freeze_panes = "B2"
    ws.auto_filter.ref = ws.dimensions


def widths(ws, cap=48):
    for col in ws.columns:
        longest = max(len(str(c.value)) if c.value is not None else 0 for c in col)
        ws.column_dimensions[get_column_letter(col[0].column)].width = min(max(longest + 2, 6), cap)


def main(path):
    data = json.load(open(path))
    stats = data["stat_labels"]
    used = [s for s in stats if any(s in i["stats"] or s in i["growth"] for i in data["items"])]
    by_item = {}
    for s in data["sources"]:
        by_item.setdefault(s["item_id"], []).append(s)

    wb = Workbook()
    ws = wb.active
    ws.title = "Items"
    cols = ["ID", "Name", "Kind", "Slot", "Rarity", "Tree", "Tier", "Element", "Teaches"]
    cols += used + [f"{s} / level" for s in used]
    cols += ["Price", "Sells for", "Stack", "Retired", "Obtained from", "Description"]
    header(ws, cols)
    for i in data["items"]:
        got = "; ".join(sorted({f"{s['how']}: {s['from']}" + (f" ({s['detail']})" if s["detail"] else "")
                                for s in by_item.get(i["id"], [])}))
        row = [i["id"], i["name"], i["kind"], i["slot"], i["rarity"], i["tree"], i["tier"] or None,
               i["element"].capitalize() or None, i["teaches"] or None]
        row += [i["stats"].get(s) for s in used] + [i["growth"].get(s) for s in used]
        row += [i["price"], i["sells_for"], i["stack"], "yes" if i["retired"] else None,
                got or ("(not obtainable)" if not i["retired"] else None), i["description"] or None]
        ws.append(row)
        fill = RARITY_FILL.get(i["rarity"])
        if fill and fill != "FFFFFF":
            ws.cell(ws.max_row, 5).fill = PatternFill("solid", fgColor=fill)
    widths(ws)

    ws = wb.create_sheet("Sources")
    header(ws, ["Item ID", "Item", "How", "From", "Where", "Chance / price / detail"])
    names = {i["id"]: i["name"] for i in data["items"]}
    for s in sorted(data["sources"], key=lambda s: (names.get(s["item_id"], s["item_id"]), s["how"], s["from"])):
        ws.append([s["item_id"], names.get(s["item_id"], s["item_id"]), s["how"], s["from"], s["where"] or None,
                   s["detail"] or None])
    widths(ws)

    ws = wb.create_sheet("Enemy Loot")
    header(ws, ["Enemy", "Level", "Found in", "Drop", "Chance", "Count", "Only while on quest"])
    for l in data["loot"]:
        ws.append([l["enemy"], l["level"], l["where"], l["item"], l["chance"], l["count"], l["quest"] or None])
        ws.cell(ws.max_row, 5).number_format = "0%"
    widths(ws, 60)

    ws = wb.create_sheet("About")
    for line in [
        "Generated from the game's content: don't edit this sheet, it is overwritten.",
        "Regenerate: godot --headless --path . res://tools/item_database.tscn -- /tmp/items.json",
        "            python3 tools/make_item_database.py /tmp/items.json",
        "Items: stats are what the item adds while worn; '/ level' columns are its growth per level",
        "(a hero gains 50% of the growth of everything worn, and of the scroll in the learning slot, at each level-up).",
        "Scrolls and tree weapons (145) are built from design/Ability_Tree.xlsx and content/tree/tuning.tres.",
        "Sells for: what a vendor pays (25% of the price).",
        "Enemy drops: personal loot, rolled for each hero who fought; a quest drop only rolls while you still need it.",
    ]:
        ws.append([line])
    ws.column_dimensions["A"].width = 110
    wb.save(OUT)
    print(f"wrote {OUT}: {len(data['items'])} items, {len(data['sources'])} sources, {len(data['loot'])} loot rows")


if __name__ == "__main__":
    main(sys.argv[1])
