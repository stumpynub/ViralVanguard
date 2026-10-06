#!/usr/bin/env python3
"""Atlas Cloud asset generator with a hard dollar budget.

Generates images, 3D models (GLB), voice (TTS) and music through Atlas Cloud and saves
them into the project. Every call is checked against a budget cap; spend is recorded in
<root>/.atlas/ledger.json together with the prompt and model (provenance for each asset).

API key: read from $ATLASCLOUD_API_KEY, $ATLAS_API_KEY, or ~/.config/atlas-assets/api_key.
It is never printed or written anywhere else.

Budget rules:
  * a job's estimated cost is reserved in the ledger BEFORE the request is sent;
  * it stays charged once Atlas accepted the job (completed, timed out, or failed to download);
  * it is released if Atlas rejected the request or reported the generation as failed.

Examples:
  atlas.py budget                       # show cap / spent / remaining
  atlas.py budget set 5                 # cap total spend at $5.00
  atlas.py image "shrimp made of bread, cursed social media photo" -o assets/generated/slop/shrimp.png
  atlas.py image "..." -o assets/generated/slop/thing.png -n 4      # 4 variations
  atlas.py model3d "low-poly graphics card" -o assets/generated/models/gpu.glb
  atlas.py voice "Certainly! Here's your slop." -o assets/generated/audio/certainly.mp3
  atlas.py music "upbeat lo-fi elevator music" -o assets/generated/music/menu.mp3 --model suno/chirp-v5 --price 0.10
  atlas.py image "..." -o x.png --dry-run   # cost estimate only
  atlas.py log                          # recent generations
"""

import argparse
import datetime as dt
import json
import math
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.atlascloud.ai/api/v1/model/"
KEY_FILE = os.path.expanduser("~/.config/atlas-assets/api_key")
USER_AGENT = "atlas-assets/0.1 (game asset tool)"
POLL_SECONDS = 2.5
MAX_BATCH = 10

# kind -> defaults. price: USD per unit; unit "run" (per generation) or "minute" (audio length).
KINDS = {
    "image": {"endpoint": "generateImage", "model": "z-image/turbo", "price": 0.01, "unit": "run", "timeout": 180, "ext": "png"},
    "model3d": {"endpoint": "generateImage", "model": "tencent/hunyuan3d-rapid/text-to-3d", "price": 0.02, "unit": "run", "timeout": 600, "ext": "glb"},
    "voice": {"endpoint": "generateAudio", "model": "bytedance/seed-audio-1.0", "price": 0.143, "unit": "minute", "timeout": 240, "ext": "mp3"},
    "music": {"endpoint": "generateAudio", "model": None, "price": None, "unit": "run", "timeout": 600, "ext": "mp3"},
    "video": {"endpoint": "generateVideo", "model": "atlascloud/wan-2.2/image-to-video", "price": 0.03, "unit": "second", "timeout": 900, "ext": "mp4"},
}
# Known per-run prices so --price can be omitted for these models (USD).
KNOWN_PRICES = {
    "z-image/turbo": 0.01,
    "black-forest-labs/flux-schnell": 0.003,
    "tencent/hunyuan3d-rapid/text-to-3d": 0.02,
    "tripo-h3.1/text-to-3d": 0.10,
    "minimax/music-3.0": 0.15,
}


# License policy: only models whose license is VERIFIED to allow commercial, royalty-free use of
# outputs. Atlas Cloud's terms don't grant output ownership for resold proprietary models, so only
# open-weight models under permissive licenses qualify. Record the source when adding one.
# See ASSET_LICENSES.md.
APPROVED_MODELS = {
    "atlascloud/wan-2.2/image-to-video": "Apache-2.0: https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B",
    "z-image/turbo": "Apache-2.0: https://huggingface.co/Tongyi-MAI/Z-Image-Turbo",
    "black-forest-labs/flux-schnell": "Apache-2.0: https://huggingface.co/black-forest-labs/FLUX.1-schnell",
}


def die(msg, code=1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


# ------------------------------------------------------------------ paths & ledger

def project_root(explicit):
    if explicit:
        return os.path.abspath(explicit)
    try:
        out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except Exception:
        return os.getcwd()


class Ledger:
    """JSON ledger shared safely between concurrent runs (flock + reload on every change)."""

    def __init__(self, root, name="ledger"):
        self.dir = os.path.join(root, ".atlas")
        self.path = os.path.join(self.dir, f"{name}.json")
        self.lock_path = os.path.join(self.dir, f"{name}.lock")
        self.data = {"cap": 0.0, "entries": []}
        self._reload()

    def _reload(self):
        if os.path.exists(self.path):
            with open(self.path) as f:
                self.data = json.load(f)

    def _locked(self):
        import fcntl
        os.makedirs(self.dir, exist_ok=True)
        lf = open(self.lock_path, "w")
        fcntl.flock(lf, fcntl.LOCK_EX)
        return lf

    def _write(self):
        tmp = self.path + f".tmp{os.getpid()}"
        with open(tmp, "w") as f:
            json.dump(self.data, f, indent=2)
        os.replace(tmp, self.path)

    def save(self):
        lf = self._locked()
        try:
            settings = {k: v for k, v in self.data.items() if k != "entries"}   # cap, flags, ...
            self._reload()
            self.data.update(settings)
            self._write()
        finally:
            lf.close()

    @property
    def cap(self):
        return float(self.data.get("cap", 0.0))

    def committed(self):
        """Spent + reserved (pending jobs count against the budget until resolved)."""
        return sum(e["cost"] for e in self.data["entries"] if e["status"] in ("pending", "done", "charged"))

    def remaining(self):
        self._reload()
        return max(0.0, self.cap - self.committed())

    def reserve(self, entry):
        """Atomically checks the budget and appends a pending entry. Returns False if it doesn't fit."""
        lf = self._locked()
        try:
            self._reload()
            if entry["cost"] > max(0.0, self.cap - self.committed()) + 1e-9:
                return False
            entry["uid"] = f"{os.getpid()}-{time.time_ns()}"
            self.data["entries"].append(entry)
            self._write()
            return True
        finally:
            lf.close()

    def update(self, entry, **kw):
        entry.update(kw)
        lf = self._locked()
        try:
            self._reload()
            for e in self.data["entries"]:
                if e.get("uid") and e.get("uid") == entry.get("uid") or (not entry.get("uid") and e.get("id") and e.get("id") == entry.get("id")):
                    e.update(entry)
                    break
            self._write()
        finally:
            lf.close()


# ------------------------------------------------------------------ HTTP

def api_key():
    for var in ("ATLASCLOUD_API_KEY", "ATLAS_API_KEY"):
        if os.environ.get(var):
            return os.environ[var].strip()
    if os.path.exists(KEY_FILE):
        with open(KEY_FILE) as f:
            k = f.read().strip()
            if k:
                return k
    die("no Atlas API key. Set ATLASCLOUD_API_KEY, or save the key to "
        f"{KEY_FILE} (chmod 600). Don't paste keys into chat.")


class HttpError(Exception):
    def __init__(self, code, msg):
        super().__init__(msg)
        self.code = code


def http(method, url, body=None, key=None, raw=False, timeout=90):
    headers = {"User-Agent": USER_AGENT, "Accept": "*/*"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if key:
        headers["Authorization"] = "Bearer " + key
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = r.read()
    except urllib.error.HTTPError as e:
        detail = e.read()[:300].decode("utf-8", "replace")
        raise HttpError(e.code, f"HTTP {e.code}: {detail}")
    except urllib.error.URLError as e:
        raise HttpError(0, f"network error: {e.reason}")
    if raw:
        return payload
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        raise HttpError(0, "non-JSON response: " + payload[:200].decode("utf-8", "replace"))


def dig(j, field):
    if isinstance(j, dict):
        if isinstance(j.get("data"), dict) and field in j["data"]:
            return j["data"][field]
        return j.get(field)
    return None


# ------------------------------------------------------------------ generation

def sniff_ext(b, fallback):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if b[:2] == b"\xff\xd8":
        return "jpg"
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return "webp"
    if b[:4] == b"RIFF":
        return "wav"
    if b[:4] == b"glTF":
        return "glb"
    if b[:4] == b"OggS":
        return "ogg"
    if b[:3] == b"ID3" or (len(b) > 1 and b[0] == 0xFF and (b[1] & 0xE0) == 0xE0):
        return "mp3"
    if b[:4] == b"\x00\x00\x00\x18" or b[4:8] == b"ftyp":
        return "mp4"
    return fallback


def estimate(kind, price, text, seconds=0):
    if KINDS[kind]["unit"] == "second":
        return price * seconds
    if KINDS[kind]["unit"] == "minute":
        secs = math.ceil(max(3.0, len(text) / 14.0) * 1.3)   # ~14 chars/sec speech, +30% margin
        return price * secs / 60.0
    return price


def build_body(kind, model, prompt, args):
    if kind == "image":
        return {"model": model, "prompt": prompt, "size": args.size, "num_images": 1, "seed": getattr(args, "seed", -1), "enable_sync_mode": False}
    if kind == "model3d":
        if model.startswith("tripo"):
            return {"model": model, "prompt": prompt, "texture": True, "pbr": True,
                    "texture_quality": "standard", "geometry_quality": "standard", "face_limit": args.faces}
        return {"model": model, "prompt": prompt, "format": "GLB"}
    if kind == "voice":
        return {"model": model, "text": prompt, "format": "mp3"}
    if kind == "video":
        return {"model": model, "image": args.image_url, "prompt": prompt, "resolution": args.resolution,
                "duration": args.seconds, "seed": -1,
                "negative_prompt": "text, watermark, logo, distorted face, jitter"}
    body = {"model": model, "prompt": prompt, "format": "mp3"}
    if args.lyrics:
        body["lyrics"] = args.lyrics
    if args.instrumental:
        body["is_instrumental"] = True
    return body


def numbered(path, i, n):
    if n == 1:
        return path
    base, ext = os.path.splitext(path)
    return f"{base}_{i + 1:02d}{ext}"


def upload_media(path, key):
    """Uploads a local file to Atlas and returns a (temporary) URL for generation inputs."""
    import uuid
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    ctype = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}.get(
        os.path.splitext(path)[1].lstrip(".").lower(), "application/octet-stream")
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: {ctype}\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(API + "uploadMedia", data=body, method="POST", headers={
        "Authorization": "Bearer " + key, "Content-Type": f"multipart/form-data; boundary={boundary}", "User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            j = json.loads(r.read())
    except urllib.error.HTTPError as e:
        die(f"upload failed: HTTP {e.code}: {e.read()[:200]}")
    url = dig(j, "download_url") or dig(j, "url")
    if not url:
        die(f"upload returned no URL: {json.dumps(j)[:200]}")
    return url


def run_one(kind, model, price, prompt, out_path, args, ledger, key):
    cost = estimate(kind, price, prompt, getattr(args, "seconds", 0))
    entry = {
        "time": dt.datetime.now().isoformat(timespec="seconds"), "kind": kind, "model": model,
        "prompt": prompt, "cost": round(cost, 6), "status": "pending", "file": None, "id": None,
        "out": out_path, "license": APPROVED_MODELS.get(model, "PLACEHOLDER: license unverified / non-commercial, replace before release" if getattr(args, "placeholder", False) else "mock"),
    }
    if not ledger.reserve(entry):
        die(f"budget: this costs ~${cost:.4f} but only ${ledger.remaining():.4f} of ${ledger.cap:.2f} is left. "
            "Ask the user before raising it (atlas.py budget set N).", 2)
    t0 = time.time()
    if kind == "video" and not args.mock:
        args.image_url = upload_media(args.image, key)
    if args.mock:
        time.sleep(0.3)
        fake = {"image": b"\x89PNG\r\n\x1a\n" + b"\x00" * 64, "model3d": b"glTF" + b"\x00" * 64}.get(kind, b"ID3" + b"\x00" * 64)
        return finish(entry, fake, out_path, ledger, t0, mock=True)
    try:
        resp = http("POST", API + KINDS[kind]["endpoint"], build_body(kind, model, prompt, args), key)
    except HttpError as e:
        ledger.update(entry, status="rejected", error=str(e))
        die(f"Atlas rejected the request ({e}). Nothing charged.")
    pid = dig(resp, "id")
    if not pid:
        ledger.update(entry, status="rejected", error="no prediction id: " + json.dumps(resp)[:200])
        die("unexpected response from Atlas (no prediction id). Nothing charged.")
    ledger.update(entry, id=pid)
    print(f"  submitted {kind} ({model}), id {pid}, ~${cost:.4f}. Waiting...", file=sys.stderr)
    return poll_and_save(entry, pid, kind, out_path, ledger, key, t0)


def poll_and_save(entry, pid, kind, out_path, ledger, key, t0):
    deadline = t0 + KINDS[kind]["timeout"]
    url = None
    while True:
        time.sleep(POLL_SECONDS)
        if time.time() > deadline:
            ledger.update(entry, status="charged", error="timed out")
            die(f"timed out after {KINDS[kind]['timeout']}s (id {pid}); cost kept as charged.")
        try:
            p = http("GET", API + "prediction/" + pid, key=key)
        except HttpError as e:
            if e.code in (401, 403, 404):
                ledger.update(entry, status="charged", error=str(e))
                die(f"polling failed: {e}")
            continue
        status = str(dig(p, "status") or "").lower()
        if status in ("completed", "succeeded", "success"):
            outs = dig(p, "outputs") or []
            url = outs[0] if outs else None
            break
        if status in ("failed", "error", "canceled", "cancelled"):
            ledger.update(entry, status="failed", error=str(dig(p, "error")))
            die(f"Atlas reported failure: {dig(p, 'error')}. Not charged.")
    if not url:
        ledger.update(entry, status="charged", error="no output url")
        die("Atlas finished but returned no output; cost kept as charged.")
    try:
        blob = http("GET", url, raw=True, timeout=180)
    except HttpError as e:
        ledger.update(entry, status="charged", error="download failed: " + str(e), output_url=url)
        die(f"download failed ({e}); output URL saved in ledger.")
    return finish(entry, blob, out_path, ledger, t0)


def finish(entry, blob, out_path, ledger, t0, mock=False):
    ext = sniff_ext(blob, os.path.splitext(out_path)[1].lstrip(".") or "bin")
    base, given = os.path.splitext(out_path)
    if given.lstrip(".").lower() not in (ext, "jpeg" if ext == "jpg" else ext):
        out_path = f"{base}.{ext}"   # keep the real format so Godot imports it correctly
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(blob)
    status = "done"
    if mock:
        entry["cost"] = 0.0
        status = "mock"
    ledger.update(entry, status=status, file=os.path.relpath(out_path, os.path.dirname(ledger.dir)))
    print(json.dumps({"file": out_path, "cost": entry["cost"], "seconds": round(time.time() - t0, 1), "mock": mock}))
    return out_path


# ------------------------------------------------------------------ CLI

def cmd_budget(args, ledger):
    if args.action == "set":
        if args.amount is None or args.amount < 0:
            die("usage: atlas.py budget set <USD>")
        ledger.data["cap"] = float(args.amount)
        ledger.save()
    elif args.action == "reset":
        lf = ledger._locked()
        try:
            ledger._reload()
            for e in ledger.data["entries"]:
                if e["status"] in ("done", "charged"):
                    e["status"] = "archived-" + e["status"]
            ledger._write()
        finally:
            lf.close()
    spent = sum(e["cost"] for e in ledger.data["entries"] if e["status"] in ("done", "charged"))
    pending = sum(e["cost"] for e in ledger.data["entries"] if e["status"] == "pending")
    print(json.dumps({"cap": ledger.cap, "spent": round(spent, 4), "pending": round(pending, 4),
                      "remaining": round(ledger.remaining(), 4), "ledger": ledger.path}))


def cmd_resume(args, ledger):
    """Finish jobs that were submitted but interrupted before download (no double charge)."""
    pending = [e for e in ledger.data["entries"] if e["status"] == "pending"]
    if not pending:
        print("nothing to resume")
        return
    key = api_key()
    for e in pending:
        if not e.get("id"):
            ledger.update(e, status="rejected", error="never submitted")
            print(f"  released unsubmitted job: {e['prompt'][:50]}", file=sys.stderr)
            continue
        out = e.get("out") or args.out
        if not out:
            die(f"job {e['id']} has no recorded output path; pass --out")
        print(f"  resuming {e['kind']} {e['id']}", file=sys.stderr)
        poll_and_save(e, e["id"], e["kind"], out, ledger, key, time.time())


def cmd_log(args, ledger):
    for e in ledger.data["entries"][-args.last:]:
        print(f"{e['time']}  {e['status']:<9} ${e['cost']:<8.4f} {e['kind']:<7} {e.get('file') or '-'}  :: {e['prompt'][:70]}")


def cmd_generate(kind, args, ledger):
    spec = KINDS[kind]
    model = args.model or spec["model"]
    if not model:
        die(f"{kind} needs --model (e.g. suno/chirp-v5) and --price.")
    price = args.price if args.price is not None else (KNOWN_PRICES.get(model) if args.model else spec["price"])
    if price is None:
        die(f"unknown price for {model}; pass --price (USD per {spec['unit']}) from the Atlas model page.")
    if getattr(args, "placeholder", False) and model not in APPROVED_MODELS:
        # The owner allowed temporary assets from unverified / non-commercial models. They must live under
        # assets/placeholder/ and be replaced before a release; the ledger marks every one.
        if "/placeholder/" not in "/" + os.path.relpath(os.path.abspath(args.out), ledger.root if hasattr(ledger, "root") else os.getcwd()).replace(os.sep, "/"):
            die("--placeholder output must go under assets/placeholder/ (it is not cleared for release).", 3)
    elif model not in APPROVED_MODELS and not args.mock:
        die(f"{model} is not on the approved-license list. Only models verified for commercial, royalty-free "
            "use may generate shipped assets (see ASSET_LICENSES.md). Add it to APPROVED_MODELS only after "
            "verifying its license from a primary source.", 3)
    n = max(1, min(MAX_BATCH, args.n))
    if kind == "video" and (not args.image or not os.path.exists(args.image)):
        die("video needs --image <first frame> (an existing approved-license image)")
    total = estimate(kind, price, args.prompt, getattr(args, "seconds", 0)) * n
    if args.dry_run:
        print(json.dumps({"kind": kind, "model": model, "n": n, "estimated_cost": round(total, 4),
                          "remaining": round(ledger.remaining(), 4), "fits": total <= ledger.remaining() + 1e-9}))
        return
    if ledger.cap <= 0:
        die("no budget set. Ask the user for a cap, then run: atlas.py budget set <USD>", 2)
    if total > ledger.remaining() + 1e-9:
        die(f"budget: {n} x ~${total / n:.4f} = ${total:.4f} exceeds remaining ${ledger.remaining():.4f}.", 2)
    key = None if args.mock else api_key()
    for i in range(n):
        run_one(kind, model, price, args.prompt, numbered(args.out, i, n), args, ledger, key)
    print(f"  remaining budget: ${ledger.remaining():.4f} of ${ledger.cap:.2f}", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", help="project root (default: git root or cwd)")
    sub = ap.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("budget", help="show or set the spending cap")
    b.add_argument("action", nargs="?", choices=["show", "set", "reset"], default="show")
    b.add_argument("amount", nargs="?", type=float)

    rs = sub.add_parser("resume", help="finish interrupted jobs without resubmitting")
    rs.add_argument("--out", help="output path for old jobs that didn't record one")

    lg = sub.add_parser("log", help="recent generations")
    lg.add_argument("--last", type=int, default=20)

    for kind in KINDS:
        g = sub.add_parser(kind, help=f"generate {kind}")
        g.add_argument("prompt", help="prompt (or the text to speak, for voice)")
        g.add_argument("-o", "--out", required=True, help="output file path (extension fixed to the real format)")
        g.add_argument("-n", type=int, default=1, help=f"number of variations (max {MAX_BATCH})")
        g.add_argument("--model", help="Atlas model id (default: %s)" % KINDS[kind]["model"])
        g.add_argument("--price", type=float, help=f"USD per {KINDS[kind]['unit']} (required for unknown models)")
        g.add_argument("--size", default="1024*1024", help="image size, e.g. 1024*1024 (image only)")
        g.add_argument("--faces", type=int, default=20000, help="max mesh faces (Tripo 3D only)")
        g.add_argument("--lyrics", help="song lyrics, may use [Verse]/[Chorus] tags (music only)")
        g.add_argument("--instrumental", action="store_true", help="no vocals (music only)")
        if kind == "video":
            g.add_argument("--image", help="first-frame image (video)")
            g.add_argument("--seconds", type=int, default=3, help="clip length 3-10 s (billed per second)")
            g.add_argument("--resolution", default="480p", choices=["480p", "720p"])
        if kind == "image":
            g.add_argument("--seed", type=int, default=-1, help="fixed seed: same seed + similar prompt = consistent images (e.g. one face, different mouths)")
        g.add_argument("--placeholder", action="store_true", help="allow a non-approved model for a TEMPORARY asset (output must be under assets/placeholder/, replace before release; owner's call)")
        g.add_argument("--dry-run", action="store_true", help="print the cost estimate and exit")
        g.add_argument("--mock", action="store_true", help="no network, free placeholder output (for testing)")

    args = ap.parse_args()
    ledger = Ledger(project_root(args.root))
    if args.cmd == "budget":
        cmd_budget(args, ledger)
    elif args.cmd == "log":
        cmd_log(args, ledger)
    elif args.cmd == "resume":
        cmd_resume(args, ledger)
    else:
        cmd_generate(args.cmd, args, ledger)


if __name__ == "__main__":
    main()
