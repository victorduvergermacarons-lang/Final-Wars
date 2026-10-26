"""Exports an .aseprite file to PNG frames (one per frame, all visible layers
composited) plus a JSON summary of layers, tags and durations. No Aseprite
needed. Usage: python3 aseprite_export.py FILE.aseprite OUT_DIR
Kept for the record (used to import the Salamander Hound, 2026-10-20)."""
import json, os, struct, sys, zlib
from PIL import Image


def read_string(b, o):
    n = struct.unpack_from("<H", b, o)[0]
    return b[o + 2:o + 2 + n].decode("utf-8"), o + 2 + n


def parse(path):
    b = open(path, "rb").read()
    size, magic, nframes, w, h, depth = struct.unpack_from("<IHHHHH", b, 0)
    assert magic == 0xA5E0, "not an aseprite file"
    transparent = b[28]
    o = 128
    layers, tags, palette, frames = [], [], {}, []
    for f in range(nframes):
        fsize, fmagic, old_chunks, dur = struct.unpack_from("<IHHH", b, o)
        new_chunks = struct.unpack_from("<I", b, o + 12)[0]
        n = new_chunks if new_chunks else old_chunks
        co = o + 16
        cels = []
        for _ in range(n):
            csize, ctype = struct.unpack_from("<IH", b, co)
            d = co + 6
            if ctype == 0x2004:
                flags, ltype, child, _, _, blend, opacity = struct.unpack_from("<HHHHHHB", b, d)
                name, _ = read_string(b, d + 16)
                layers.append({"name": name, "flags": flags, "type": ltype, "child": child,
                               "blend": blend, "opacity": opacity})
            elif ctype == 0x2005:
                li, x, y, op, ct, z = struct.unpack_from("<HhhBHh", b, d)
                p = d + 16
                if ct == 1:
                    cels.append({"layer": li, "link": struct.unpack_from("<H", b, p)[0]})
                elif ct in (0, 2):
                    cw, ch = struct.unpack_from("<HH", b, p)
                    raw = b[p + 4:co + csize]
                    if ct == 2:
                        raw = zlib.decompress(raw)
                    cels.append({"layer": li, "x": x, "y": y, "opacity": op, "w": cw, "h": ch, "data": raw})
            elif ctype == 0x2018:
                nt = struct.unpack_from("<H", b, d)[0]
                p = d + 10
                for _ in range(nt):
                    fr, to, direction = struct.unpack_from("<HHB", b, p)
                    p += 17
                    name, p = read_string(b, p)
                    tags.append({"name": name, "from": fr, "to": to, "direction": direction})
            elif ctype == 0x2019:
                psize, first, last = struct.unpack_from("<III", b, d)
                p = d + 20
                for i in range(first, last + 1):
                    fl = struct.unpack_from("<H", b, p)[0]
                    palette[i] = tuple(b[p + 2:p + 6])
                    p += 6
                    if fl & 1:
                        _, p = read_string(b, p)
            co += csize
        frames.append({"duration": dur, "cels": cels})
        o += fsize
    return {"w": w, "h": h, "depth": depth, "transparent": transparent,
            "layers": layers, "tags": tags, "palette": palette, "frames": frames}


def cel_image(doc, cel):
    w, h, data = cel["w"], cel["h"], cel["data"]
    if doc["depth"] == 32:
        return Image.frombytes("RGBA", (w, h), data)
    if doc["depth"] == 16:
        im = Image.frombytes("LA", (w, h), data)
        return im.convert("RGBA")
    out = Image.new("RGBA", (w, h))
    px = out.load()
    for i, v in enumerate(data):
        if v != doc["transparent"]:
            px[i % w, i // w] = doc["palette"].get(v, (0, 0, 0, 0))
    return out


def render(doc, f, only_layers=None):
    img = Image.new("RGBA", (doc["w"], doc["h"]))
    cels = sorted(doc["frames"][f]["cels"], key=lambda c: c["layer"])
    for cel in cels:
        layer = doc["layers"][cel["layer"]]
        if only_layers is not None:
            if layer["name"] not in only_layers:
                continue
        elif not layer["flags"] & 1:
            continue
        if "link" in cel:
            src = [c for c in doc["frames"][cel["link"]]["cels"] if c["layer"] == cel["layer"]]
            if not src:
                continue
            cel = src[0]
        im = cel_image(doc, cel)
        a = cel["opacity"] * layer["opacity"] / 255.0
        if a < 1.0:
            alpha = im.getchannel("A").point(lambda v: int(v * a))
            im.putalpha(alpha)
        img.alpha_composite(im, (cel["x"], cel["y"]))
    return img


if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    doc = parse(src)
    for f in range(len(doc["frames"])):
        render(doc, f).save(os.path.join(out, "frame_%03d.png" % f))
    summary = {k: doc[k] for k in ("w", "h", "depth", "layers", "tags")}
    summary["durations"] = [fr["duration"] for fr in doc["frames"]]
    json.dump(summary, open(os.path.join(out, "summary.json"), "w"), indent=1)
    print(json.dumps(summary, indent=1))
