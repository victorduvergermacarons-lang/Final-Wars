#!/usr/bin/env python3
"""Daily PixelLab art bot for Final Wars.

Takes the next prompts from queue.json, spends up to the day's generations on
PixelLab, and saves each picture as a draft in the drafts folder (the
art-drafts branch when run by .github/workflows/art-bot.yml). Nothing here
touches the game: a person reviews the drafts and copies the keepers into
assets/.

Building on approved pictures: a draft becomes a base once it is copied to
approved/<KEY>.png on the drafts branch (for example approved/PL-01-1.png).
Prompts with a "base" (a new weapon or outfit on the same character) wait
until their base is approved, then edit that picture. Once every still is
done, each approved character still gets its 8 directions and the animations
listed in the queue, all made from the approved picture.

Usage:
    PIXELLAB_SECRET=... python3 tools/art_bot/art_bot.py --drafts drafts [--count 5] [--dry-run]

Only the standard library is needed. Pillow, if installed, converts raw RGBA
image data and makes the animation sheets and GIF previews.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
API = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
GENERATE_ENDPOINT = "/create-image-pixflux"
EDIT_ENDPOINT = "/edit-image-pixen"       # keeps the pose and style, changes what the text asks
EDIT_FALLBACK_ENDPOINT = "/edit-image"
ROTATE_ENDPOINT = "/generate-8-rotations-v3"
ANIMATE_ENDPOINT = "/animate-with-text-v3"
USER_AGENT = "final-wars-art-bot/1.1"
POLL_SECONDS = int(os.environ.get("ART_BOT_POLL", "5"))
JOB_TIMEOUT_SECONDS = 1800  # slow (free daily) generations can wait in a queue
MAX_FAILURES = 3  # a prompt that fails this many times is skipped until reset
DEFAULT_FRAMES = 8

# Answers that mean "no generations left today": stop instead of retrying.
OUT_OF_CREDITS_STATUS = {402, 429}
OUT_OF_CREDITS_WORDS = ("insufficient", "no generations", "limit reached", "quota", "out of credits",
                        "subscription", "upgrade", "trial", "not available on your plan")

KEY_RE = re.compile(r"^([A-Z]{2}-\d{2}-\d+)")


class OutOfCredits(Exception):
    pass


class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body[:500]}")
        self.status = status
        self.body = body


# ---------------------------------------------------------------- queue

def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:40]


def load_queue(path: Path) -> list[dict]:
    """The stills, in queue order. Follow-ups (8 directions, animations) come from followups()."""
    data = json.loads(path.read_text(encoding="utf-8"))
    kinds = data["kinds"]
    entries = []
    for item in data["items"]:
        for n, prompt in enumerate(item["prompts"], start=1):
            kind = kinds[prompt.get("kind", item.get("kind", "plain"))]
            size = prompt.get("size") or kind["size"]
            text = prompt["subject"].rstrip()
            if kind.get("suffix"):
                text = f"{text} {kind['suffix']}"
            entries.append({
                "key": f"{item['id']}-{n}",
                "id": item["id"],
                "asset": item["asset"],
                "act": item["act"],
                "op": "edit" if prompt.get("base") else "generate",
                "base": prompt.get("base", ""),
                "description": text,
                "width": size[0],
                "height": size[1],
                "no_background": prompt.get("no_background", kind.get("no_background", True)),
                "rotate": prompt.get("rotate", bool(prompt.get("animations"))),
                "animations": prompt.get("animations", []),
                "frames": prompt.get("frames", DEFAULT_FRAMES),
            })
    return entries


def followups(stills: list[dict], approved: dict[str, Path]) -> list[dict]:
    """8 directions and animations for every approved still that lists them."""
    out = []
    for s in stills:
        if s["key"] not in approved:
            continue
        common = {"id": s["id"], "asset": s["asset"], "act": s["act"], "base": s["key"],
                  "width": s["width"], "height": s["height"], "no_background": True,
                  "animations": [], "rotate": False}
        if s["rotate"]:
            out.append({**common, "key": f"{s['key']}+8dir", "op": "rotate8",
                        "description": "8 directions of the approved picture"})
        for action in s["animations"]:
            out.append({**common, "key": f"{s['key']}+{slug(action)}", "op": "animate",
                        "description": action, "frames": s["frames"]})
    return out


def load_approved(drafts: Path) -> dict[str, Path]:
    """approved/<KEY>.png on the drafts branch. A name like PL-01-1_2026-11-06.png counts too."""
    found = {}
    folder = drafts / "approved"
    if folder.is_dir():
        for f in sorted(folder.glob("*.png")):
            m = KEY_RE.match(f.stem)
            if m:
                found[m.group(1)] = f
    return found


def load_progress(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"done": {}, "failures": {}, "runs": []}


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def pending(entries: list[dict], progress: dict) -> list[dict]:
    return [e for e in entries
            if e["key"] not in progress["done"]
            and progress["failures"].get(e["key"], {}).get("count", 0) < MAX_FAILURES]


def plan(stills: list[dict], approved: dict[str, Path], progress: dict, count: int):
    """Today's work: stills first (the tracker's rule: animations after every reference),
    skipping those whose base isn't approved yet; then the follow-ups."""
    open_stills = pending(stills, progress)
    ready = [e for e in open_stills if not e["base"] or e["base"] in approved]
    waiting = [e for e in open_stills if e["base"] and e["base"] not in approved]
    later = pending(followups(stills, approved), progress)
    return (ready + later)[:count], waiting  # follow-ups only use what the stills leave


# ---------------------------------------------------------------- API

def request(method: str, path: str, secret: str, body: dict | None = None) -> tuple[int, dict]:
    url = path if path.startswith("http") else f"{API}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {secret}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    })
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            raw = resp.read().decode("utf-8", "replace")
            return resp.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as err:
        text = err.read().decode("utf-8", "replace")
        # Account problems (no generations left, plan doesn't allow the API) stop today's run
        # without counting against the prompt, so no prompt gets skipped for it.
        if err.code in OUT_OF_CREDITS_STATUS or any(w in text.lower() for w in OUT_OF_CREDITS_WORDS):
            raise OutOfCredits(f"HTTP {err.code}: {text[:300]}") from None
        raise ApiError(err.code, text) from None


def job_id(payload) -> str | None:
    if isinstance(payload, dict):
        for key in ("background_job_id", "job_id"):
            if isinstance(payload.get(key), str) and payload[key]:
                return payload[key]
        if "process" in str(payload.get("status", "")).lower() and isinstance(payload.get("id"), str):
            return payload["id"]
        for value in payload.values():
            found = job_id(value)
            if found:
                return found
    elif isinstance(payload, list):
        for value in payload:
            found = job_id(value)
            if found:
                return found
    return None


def wait_for_job(first: dict, secret: str) -> dict:
    jid = job_id(first)
    if not jid or find_images(first):
        return first
    deadline = time.time() + JOB_TIMEOUT_SECONDS
    while time.time() < deadline:
        time.sleep(POLL_SECONDS)
        _, payload = request("GET", f"/background-jobs/{jid}", secret)
        status = str(payload.get("status", "")).lower()
        if status in ("completed", "complete", "succeeded", "success"):
            return payload.get("last_response") if isinstance(payload.get("last_response"), dict) else payload
        if status in ("failed", "error", "cancelled", "canceled"):
            raise ApiError(0, f"job {jid} {status}: {json.dumps(payload)[:400]}")
    raise ApiError(0, f"job {jid} still running after {JOB_TIMEOUT_SECONDS} s")


def find_images(payload) -> list[dict]:
    found = []
    if isinstance(payload, dict):
        if isinstance(payload.get("base64"), str) and payload["base64"]:
            found.append(payload)
        for value in payload.values():
            found.extend(find_images(value))
    elif isinstance(payload, list):
        for value in payload:
            found.extend(find_images(value))
    return found


def to_png(image: dict, width: int, height: int) -> bytes:
    raw = image["base64"]
    if "," in raw and "base64" in raw.split(",", 1)[0]:
        raw = raw.split(",", 1)[1]
    data = base64.b64decode(raw.replace("\n", "").replace("\r", ""))
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return data
    # Raw RGBA pixels ("rgba_bytes"): needs Pillow and the picture's size.
    w = int(image.get("width") or width)
    h = int(image.get("height") or height)
    if len(data) == w * h * 4:
        from PIL import Image  # installed by the workflow
        out = io.BytesIO()
        Image.frombytes("RGBA", (w, h), data).save(out, format="PNG")
        return out.getvalue()
    return data  # unknown format: keep the bytes so nothing is lost


def png_size(png: bytes) -> tuple[int, int]:
    if png[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("the approved picture is not a PNG")
    return int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")


def image_obj(png: bytes) -> dict:
    return {"type": "base64", "base64": base64.b64encode(png).decode(), "format": "png"}


def post(endpoint: str, body: dict, secret: str) -> dict:
    _, first = request("POST", endpoint, secret, body)
    return wait_for_job(first, secret)


def generate(entry: dict, secret: str, approved: dict[str, Path]) -> tuple[list[bytes], dict]:
    op = entry["op"]
    w, h = entry["width"], entry["height"]
    if op == "generate":
        body = {"description": entry["description"], "image_size": {"width": w, "height": h}}
        if entry["no_background"]:
            body["no_background"] = True
        try:
            result = post(GENERATE_ENDPOINT, body, secret)
        except ApiError as err:
            if err.status != 422 or "no_background" not in body:
                raise
            body.pop("no_background")  # older endpoints may not take it
            result = post(GENERATE_ENDPOINT, body, secret)
    else:
        base_png = approved[entry["base"]].read_bytes()
        bw, bh = png_size(base_png)
        if op == "edit":
            body = {"image": image_obj(base_png), "description": entry["description"],
                    "width": w, "height": h, "no_background": True}
            try:
                result = post(EDIT_ENDPOINT, body, secret)
            except ApiError as err:
                if err.status not in (404, 405, 422):
                    raise
                print(f"   {EDIT_ENDPOINT} refused it ({err.status}); trying {EDIT_FALLBACK_ENDPOINT}")
                body["image_size"] = {"width": bw, "height": bh}
                result = post(EDIT_FALLBACK_ENDPOINT, body, secret)
        elif op == "rotate8":
            result = post(ROTATE_ENDPOINT, {"first_frame": image_obj(base_png), "no_background": True}, secret)
            w, h = bw, bh
        elif op == "animate":
            result = post(ANIMATE_ENDPOINT, {"first_frame": image_obj(base_png), "action": entry["description"],
                                             "frame_count": entry.get("frames", DEFAULT_FRAMES),
                                             "no_background": True}, secret)
            w, h = bw, bh
        else:
            raise ValueError(f"unknown step {op}")
    images = find_images(result)
    if not images:
        raise ApiError(0, f"no image in the answer: {json.dumps(result)[:400]}")
    usage = result.get("usage") if isinstance(result, dict) else None
    return [to_png(i, w, h) for i in images], (usage or {})


def make_sheet_and_gif(pngs: list[bytes], folder: Path, stem: str, gif: bool) -> list[str]:
    """A one-row sheet of the frames, and a looping GIF preview for animations."""
    try:
        from PIL import Image
    except ImportError:
        return []
    frames = [Image.open(io.BytesIO(p)).convert("RGBA") for p in pngs]
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * w, 0))
    made = [f"{stem}_sheet.png"]
    sheet.save(folder / made[0])
    if gif:
        scale = max(1, 192 // max(w, h))  # big enough to judge on GitHub
        big = [f.resize((f.width * scale, f.height * scale), Image.NEAREST) for f in frames]
        made.append(f"{stem}_preview.gif")
        big[0].save(folder / made[1], save_all=True, append_images=big[1:], duration=100,
                    loop=0, disposal=2, transparency=0)
    return made


# ---------------------------------------------------------------- review page

def write_review(drafts: Path, stills: list[dict], approved: dict[str, Path], progress: dict,
                 waiting: list[dict]) -> None:
    done = progress["done"]
    stills_done = sum(1 for s in stills if s["key"] in done)
    lines = [
        "# Art drafts",
        "",
        "Made by the art bot (`tools/art_bot/` on the main branch) from the art tracker's prompts.",
        f"{stills_done} of {len(stills)} stills done. Newest first. These are drafts: copy the",
        "keepers into the game's `assets/` folder by hand.",
        "",
        "**To build on a draft** (new weapon or outfit, 8 directions, animations), copy it to",
        "`approved/<KEY>.png` on this branch, for example `approved/PL-01-1.png`.",
        "",
    ]
    if waiting:
        lines += ["## Waiting for an approved base", ""]
        by_base: dict[str, list[str]] = {}
        for e in waiting:
            by_base.setdefault(e["base"], []).append(e["key"])
        for base, keys in by_base.items():
            lines.append(f"- `approved/{base}.png` unlocks {', '.join(keys)}")
        lines.append("")
    unlockable = [s for s in stills if s["key"] in done and s["key"] not in approved
                  and (s["rotate"] or s["animations"])]
    if unlockable:
        lines += ["## Approve to animate", ""]
        for s in unlockable:
            extra = (["8 directions"] if s["rotate"] else []) + s["animations"]
            lines.append(f"- `approved/{s['key']}.png` unlocks {', '.join(extra)}")
        lines.append("")
    failed = {k: v for k, v in progress["failures"].items() if k not in done}
    if failed:
        lines += ["## Failed (retried next run, skipped after 3 tries)", ""]
        for key, info in failed.items():
            lines.append(f"- **{key}** ({info['count']}x): {info['last_error'][:160]}")
        lines.append("")
    by_key = {e["key"]: e for e in stills + followups(stills, approved)}
    lines += ["## Drafts", ""]
    for key, info in sorted(done.items(), key=lambda kv: kv[1]["date"], reverse=True):
        e = by_key.get(key, {})
        mark = " ✓ approved" if key in approved else ""
        lines.append(f"### {key} · {e.get('asset', '')} ({info['date']}){mark}")
        lines.append("")
        shown = info.get("preview") or info["files"]
        lines.append(" ".join(f"![{key}]({f})" for f in shown))
        lines.append("")
        if e.get("base"):
            lines.append(f"<sub>Made from approved/{e['base']}.png: {e.get('description', '')[:300]}</sub>")
        else:
            lines.append(f"<sub>{e.get('description', '')[:300]}</sub>")
        lines.append("")
    (drafts / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--drafts", default="drafts", help="folder of the art-drafts branch")
    ap.add_argument("--queue", default=str(HERE / "queue.json"))
    ap.add_argument("--count", type=int, default=int(os.environ.get("DAILY_GENERATIONS", "5")))
    ap.add_argument("--dry-run", action="store_true", help="show what would be made, call nothing")
    args = ap.parse_args()

    drafts = Path(args.drafts)
    stills = load_queue(Path(args.queue))
    approved = load_approved(drafts)
    progress_path = drafts / "progress.json"
    progress = load_progress(progress_path)
    todo, waiting = plan(stills, approved, progress, args.count)
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()

    print(f"Queue: {len(stills)} stills, {len(progress['done'])} drafts done, "
          f"{len(approved)} approved, {len(waiting)} waiting for an approved base, {len(todo)} to try today.")
    for base in sorted({e["base"] for e in waiting}):
        print(f"  waiting for approved/{base}.png: {', '.join(e['key'] for e in waiting if e['base'] == base)}")
    if args.dry_run:
        for e in todo:
            print(f"  {e['key']} [{e['op']}] {e['width']}x{e['height']}: {e['description'][:90]}")
        return 0
    if not todo:
        write_review(drafts, stills, approved, progress, waiting)
        print("Nothing to make today.")
        return 0

    secret = os.environ.get("PIXELLAB_SECRET", "").strip()
    if not secret:
        print("PIXELLAB_SECRET is not set (GitHub: Settings > Secrets and variables > Actions).")
        return 1

    try:
        _, balance = request("GET", "/balance", secret)
        print(f"Balance before: {json.dumps(balance)}")
    except (ApiError, OutOfCredits) as err:
        print(f"Couldn't read the balance ({err}); carrying on.")

    made, errors = 0, 0
    run = {"date": today, "made": [], "failed": [], "stopped": ""}
    for e in todo:
        print(f"-> {e['key']} [{e['op']}] ({e['asset']}) {e['width']}x{e['height']}")
        try:
            pngs, usage = generate(e, secret, approved)
        except OutOfCredits as err:
            print(f"   Stopping for today (generations or plan): {err}")
            run["stopped"] = "out of generations"
            break
        except (ApiError, urllib.error.URLError, OSError, ValueError) as err:
            errors += 1
            info = progress["failures"].setdefault(e["key"], {"count": 0})
            info["count"] += 1
            info["last_error"] = str(err)
            run["failed"].append(e["key"])
            print(f"   Failed: {err}")
            if isinstance(err, ApiError) and err.status == 401:
                print("   The key was refused; stopping.")
                run["stopped"] = "key refused"
                break
            continue
        folder = drafts / "art" / e["id"]
        folder.mkdir(parents=True, exist_ok=True)
        stem = f"{e['key']}_{today}"
        files = []
        for i, png in enumerate(pngs):
            name = f"{stem}_{i + 1}.png" if len(pngs) > 1 else f"{stem}.png"
            (folder / name).write_bytes(png)
            files.append(f"art/{e['id']}/{name}")
        record = {"date": today, "files": files, "usage": usage}
        if e["op"] in ("rotate8", "animate") and len(pngs) > 1:
            extra = make_sheet_and_gif(pngs, folder, stem, gif=e["op"] == "animate")
            if extra:
                record["preview"] = [f"art/{e['id']}/{extra[-1]}"]
        progress["done"][e["key"]] = record
        progress["failures"].pop(e["key"], None)
        run["made"].append(e["key"])
        made += 1
        print(f"   Saved {len(files)} picture(s) in art/{e['id']}/")
        save_json(progress_path, progress)  # keep what's made even if a later call crashes

    progress["runs"] = (progress.get("runs", []) + [run])[-60:]
    save_json(progress_path, progress)
    write_review(drafts, stills, approved, progress, waiting)
    print(f"Made {made}, failed {errors}.")
    # Fail the workflow (GitHub emails you) only when nothing worked and it wasn't just credits.
    return 1 if made == 0 and errors > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
