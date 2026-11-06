#!/usr/bin/env python3
"""Daily PixelLab art bot for Final Wars.

Takes the next prompts from queue.json, spends up to the day's generations on
PixelLab, and saves each picture as a draft in the drafts folder (the
art-drafts branch when run by .github/workflows/art-bot.yml). Nothing here
touches the game: a person reviews the drafts and copies the keepers into
assets/.

Usage:
    PIXELLAB_SECRET=... python3 tools/art_bot/art_bot.py --drafts drafts [--count 5] [--dry-run]

Only the standard library is needed. Pillow is used if installed, to convert
raw RGBA image data to PNG.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
API = os.environ.get("PIXELLAB_BASE_URL", "https://api.pixellab.ai/v2").rstrip("/")
ENDPOINT = os.environ.get("PIXELLAB_ENDPOINT", "/create-image-pixflux")
USER_AGENT = "final-wars-art-bot/1.0"
POLL_SECONDS = int(os.environ.get("ART_BOT_POLL", "5"))
JOB_TIMEOUT_SECONDS = 600
MAX_FAILURES = 3  # a prompt that fails this many times is skipped until reset

# Answers that mean "no generations left today": stop instead of retrying.
OUT_OF_CREDITS_STATUS = {402, 429}
OUT_OF_CREDITS_WORDS = ("insufficient", "no generations", "limit reached", "quota", "out of credits")


class OutOfCredits(Exception):
    pass


class ApiError(Exception):
    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body[:500]}")
        self.status = status
        self.body = body


# ---------------------------------------------------------------- queue

def load_queue(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    kinds = data["kinds"]
    entries = []
    for item in data["items"]:
        for n, prompt in enumerate(item["prompts"], start=1):
            kind = kinds[prompt.get("kind", item.get("kind"))]
            size = prompt.get("size") or kind["size"]
            text = prompt["subject"].rstrip()
            if kind.get("suffix"):
                text = f"{text} {kind['suffix']}"
            entries.append({
                "key": f"{item['id']}-{n}",
                "id": item["id"],
                "asset": item["asset"],
                "act": item["act"],
                "description": text,
                "width": size[0],
                "height": size[1],
                "no_background": prompt.get("no_background", kind.get("no_background", True)),
                "animation": prompt.get("animation", ""),
            })
    return entries


def load_progress(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"done": {}, "failures": {}, "runs": []}


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def next_entries(entries: list[dict], progress: dict, count: int) -> list[dict]:
    todo = []
    for e in entries:
        if e["key"] in progress["done"]:
            continue
        if progress["failures"].get(e["key"], {}).get("count", 0) >= MAX_FAILURES:
            continue
        todo.append(e)
        if len(todo) >= count:
            break
    return todo


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


def generate(entry: dict, secret: str) -> tuple[list[bytes], dict]:
    body = {
        "description": entry["description"],
        "image_size": {"width": entry["width"], "height": entry["height"]},
    }
    if entry["no_background"]:
        body["no_background"] = True
    try:
        _, first = request("POST", ENDPOINT, secret, body)
    except ApiError as err:
        if err.status == 422 and "no_background" in body:
            body.pop("no_background")  # older endpoints may not take it
            _, first = request("POST", ENDPOINT, secret, body)
        else:
            raise
    result = wait_for_job(first, secret)
    images = find_images(result)
    if not images:
        raise ApiError(0, f"no image in the answer: {json.dumps(result)[:400]}")
    usage = result.get("usage") if isinstance(result, dict) else None
    return [to_png(i, entry["width"], entry["height"]) for i in images], (usage or {})


# ---------------------------------------------------------------- review page

def write_review(drafts: Path, entries: list[dict], progress: dict) -> None:
    done = progress["done"]
    lines = [
        "# Art drafts",
        "",
        "Made by the art bot (`tools/art_bot/` on the main branch) from the art tracker's prompts.",
        f"{len(done)} of {len(entries)} prompts done. Newest first. These are drafts: copy the",
        "keepers into the game's `assets/` folder by hand.",
        "",
    ]
    failed = {k: v for k, v in progress["failures"].items() if k not in done}
    if failed:
        lines += ["## Failed (retried next run, skipped after 3 tries)", ""]
        for key, info in failed.items():
            lines.append(f"- **{key}** ({info['count']}x): {info['last_error'][:160]}")
        lines.append("")
    by_key = {e["key"]: e for e in entries}
    lines += ["## Drafts", ""]
    for key, info in sorted(done.items(), key=lambda kv: kv[1]["date"], reverse=True):
        e = by_key.get(key, {})
        lines.append(f"### {key} · {e.get('asset', '')} ({info['date']})")
        lines.append("")
        for f in info["files"]:
            lines.append(f"![{key}]({f})")
        lines.append("")
        lines.append(f"<sub>{e.get('description', '')[:300]}</sub>")
        if e.get("animation"):
            lines.append(f"<sub>Animation still to do: {e['animation']}</sub>")
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
    entries = load_queue(Path(args.queue))
    progress_path = drafts / "progress.json"
    progress = load_progress(progress_path)
    todo = next_entries(entries, progress, args.count)
    today = dt.datetime.now(dt.timezone.utc).date().isoformat()

    print(f"Queue: {len(entries)} prompts, {len(progress['done'])} done, {len(todo)} to try today.")
    if args.dry_run:
        for e in todo:
            print(f"  {e['key']} {e['width']}x{e['height']}: {e['description'][:90]}")
        return 0
    if not todo:
        print("Nothing left in the queue.")
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
        print(f"-> {e['key']} ({e['asset']}) {e['width']}x{e['height']}")
        try:
            pngs, usage = generate(e, secret)
        except OutOfCredits as err:
            print(f"   Out of generations for today: {err}")
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
        files = []
        folder = drafts / "art" / e["id"]
        folder.mkdir(parents=True, exist_ok=True)
        for i, png in enumerate(pngs):
            suffix = f"_{i + 1}" if len(pngs) > 1 else ""
            name = f"{e['key']}_{today}{suffix}.png"
            (folder / name).write_bytes(png)
            files.append(f"art/{e['id']}/{name}")
        progress["done"][e["key"]] = {"date": today, "files": files, "usage": usage}
        progress["failures"].pop(e["key"], None)
        run["made"].append(e["key"])
        made += 1
        print(f"   Saved {', '.join(files)}")
        save_json(progress_path, progress)  # keep what's made even if a later call crashes

    progress["runs"] = (progress.get("runs", []) + [run])[-60:]
    save_json(progress_path, progress)
    write_review(drafts, entries, progress)
    print(f"Made {made}, failed {errors}. {len(progress['done'])} of {len(entries)} prompts done.")
    # Fail the workflow (GitHub emails you) only when nothing worked and it wasn't just credits.
    return 1 if made == 0 and errors > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
