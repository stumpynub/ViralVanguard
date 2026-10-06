#!/usr/bin/env python3
"""Tripo 3D (direct Tripo API v3) generator with a hard credit budget.

Turns an image (e.g. an approved-license prop render) or a text prompt into a textured GLB.
Billing is in Tripo credits; the cap and every task are recorded in <root>/.atlas/tripo_ledger.json.

LICENSE GATE: Tripo's Terms (§5.2.2, updated 2025-07-11) give PAID users all rights to outputs,
royalty-free; outputs of FREE users belong to Tripo (§5.2.1). So this tool refuses to run until the
account owner has confirmed the API account is paid: `tripo.py confirm-paid`.

API key: $TRIPO_API_KEY or ~/.config/atlas-assets/tripo_key (never printed).

  tripo.py balance                          # Tripo account balance + local cap
  tripo.py budget set 2000                  # cap total credits this tool may spend
  tripo.py image3d assets/generated/prop_refs/x.png -o assets/generated/models/x.glb
  tripo.py text3d "a cartoon shrimp figurine" -o assets/generated/models/shrimp.glb
  tripo.py log
"""
import argparse
import datetime as dt
import json
import os
import sys
import time
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atlas import HttpError, Ledger, die, http, project_root, sniff_ext  # noqa: E402

API = "https://openapi.tripo3d.ai/v3"
KEY_FILE = os.path.expanduser("~/.config/atlas-assets/tripo_key")
DEFAULT_MODEL = "v3.1-20260211"
EST_CREDITS = 60.0     # reservation per task until real usage is known; refined from the ledger
TIMEOUT = 600


def key():
    if os.environ.get("TRIPO_API_KEY"):
        return os.environ["TRIPO_API_KEY"].strip()
    if os.path.exists(KEY_FILE):
        with open(KEY_FILE) as f:
            k = f.read().strip()
            if k:
                return k
    die(f"no Tripo API key. Save it to {KEY_FILE} (chmod 600) or set TRIPO_API_KEY.")


def api(method, path, body=None, k=None):
    try:
        r = http(method, API + path, body, k)
    except HttpError as e:
        raise HttpError(e.code, str(e))
    if not isinstance(r, dict) or r.get("code") != 0:
        msg = r.get("message") if isinstance(r, dict) else r
        raise HttpError(0, f"Tripo error {r.get('code') if isinstance(r, dict) else '?'}: {msg} {r.get('suggestion', '') if isinstance(r, dict) else ''}")
    return r.get("data")


def upload(path, k):
    import urllib.request
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    ext = os.path.splitext(path)[1].lstrip(".").lower()
    ctype = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}.get(ext, "application/octet-stream")
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: {ctype}\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(API + "/files", data=body, method="POST", headers={
        "Authorization": "Bearer " + k, "Content-Type": f"multipart/form-data; boundary={boundary}",
        "User-Agent": "atlas-assets/0.1"})
    with urllib.request.urlopen(req, timeout=120) as r:
        j = json.loads(r.read())
    if j.get("code") != 0:
        die(f"upload failed: {j.get('message')}")
    return j["data"]["file_token"]


def est(ledger):
    used = [e["cost"] for e in ledger.data["entries"] if e["status"] == "done" and e.get("cost")]
    return max(used) * 1.1 if used else EST_CREDITS


def run(kind, src, out, args, ledger):
    if kind == "image3d" and not os.path.exists(src):
        die(f"no such image: {src}")
    if not ledger.data.get("paid_confirmed"):
        die("license gate: confirm the Tripo API account is PAID (outputs of free accounts belong to Tripo, "
            "Terms §5.2.1). After the owner confirms, run: tripo.py confirm-paid", 3)
    if ledger.cap <= 0:
        die("no Tripo credit cap set. Ask the user, then: tripo.py budget set <credits>", 2)
    k = key()
    reserve = args.expect if getattr(args, "expect", 0) else est(ledger)
    entry = {"time": dt.datetime.now().isoformat(timespec="seconds"), "kind": kind, "model": args.model,
             "prompt": src, "cost": round(reserve, 2), "status": "pending", "file": None, "id": None, "out": out,
             "license": "Tripo Terms §5.2.2 (paid user owns outputs, royalty-free)"}
    if not ledger.reserve(entry):
        die(f"budget: ~{reserve:.0f} credits needed, only {ledger.remaining():.0f} of {ledger.cap:.0f} left.", 2)
    t0 = time.time()
    body = {"model": args.model, "texture": True, "pbr": True, "texture_quality": args.texture_quality,
            "face_limit": args.faces}
    try:
        if kind == "image3d":
            body["input"] = upload(src, k)
            body["orientation"] = "default"
            data = api("POST", "/generation/image-to-model", body, k)
        else:
            body["prompt"] = src
            data = api("POST", "/generation/text-to-model", body, k)
    except (HttpError, OSError) as e:
        ledger.update(entry, status="rejected", error=str(e))
        die(f"request not submitted ({e}). Nothing charged.")
    tid = data["task_id"]
    ledger.update(entry, id=tid)
    print(f"  submitted {kind} task {tid} (reserved ~{reserve:.0f} credits). Waiting...", file=sys.stderr)
    while True:
        time.sleep(3)
        if time.time() - t0 > TIMEOUT:
            ledger.update(entry, status="charged", error="timed out")
            die(f"timed out (task {tid}); run `tripo.py resume` later.")
        try:
            task = api("GET", f"/tasks/{tid}", k=k)
        except HttpError:
            continue
        st = task.get("status")
        if st == "success":
            break
        if st in ("failed", "cancelled", "banned", "expired"):
            ledger.update(entry, status="failed", error=st)
            die(f"Tripo task {st}. Failed/cancelled tasks are not charged by Tripo.")
    return finish(entry, task, out, ledger, t0)


def finish(entry, task, out, ledger, t0):
    url = (task.get("output") or {}).get("model_url")
    if not url:
        ledger.update(entry, status="charged", error="no model_url")
        die("task finished without a model_url")
    blob = http("GET", url, raw=True, timeout=300)
    ext = sniff_ext(blob, "glb")
    if not out.endswith("." + ext):
        out = os.path.splitext(out)[0] + "." + ext
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "wb") as f:
        f.write(blob)
    credits = float(task.get("credits_consumed") or entry["cost"])
    ledger.update(entry, status="done", cost=credits, file=os.path.relpath(out, os.path.dirname(ledger.dir)))
    print(json.dumps({"file": out, "credits": credits, "seconds": round(time.time() - t0, 1),
                      "size_mb": round(len(blob) / 1e6, 2)}))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("budget")
    b.add_argument("action", nargs="?", choices=["show", "set"], default="show")
    b.add_argument("amount", nargs="?", type=float)
    sub.add_parser("balance")
    sub.add_parser("confirm-paid", help="record that the account owner confirmed the API account is paid")
    sub.add_parser("log")
    rs = sub.add_parser("resume")
    for kind in ("image3d", "text3d"):
        g = sub.add_parser(kind)
        g.add_argument("src", help="image path (image3d) or prompt (text3d)")
        g.add_argument("-o", "--out", required=True)
        g.add_argument("--model", default=DEFAULT_MODEL)
        g.add_argument("--faces", type=int, default=20000, help="max faces (game props: 10k-50k)")
        g.add_argument("--texture-quality", default="standard", choices=["standard", "detailed"])
        g.add_argument("--expect", type=float, default=0, help="reserve exactly this many credits (known price); still checked against the cap")
    args = ap.parse_args()
    ledger = Ledger(project_root(args.root), "tripo_ledger")
    if args.cmd == "budget":
        if args.action == "set":
            ledger.data["cap"] = float(args.amount)
            ledger.save()
        print(json.dumps({"cap_credits": ledger.cap, "committed": round(ledger.committed(), 2),
                          "remaining": round(ledger.remaining(), 2), "paid_confirmed": bool(ledger.data.get("paid_confirmed"))}))
    elif args.cmd == "confirm-paid":
        ledger.data["paid_confirmed"] = dt.datetime.now().isoformat(timespec="seconds")
        ledger.save()
        print("recorded: account owner confirmed the Tripo API account is paid")
    elif args.cmd == "balance":
        d = api("GET", "/account/balance", k=key())
        print(json.dumps({"tripo_balance": d.get("balance"), "frozen": d.get("frozen"), "local_cap": ledger.cap,
                          "local_remaining": round(ledger.remaining(), 2)}))
    elif args.cmd == "log":
        for e in ledger.data["entries"][-30:]:
            print(f"{e['time']}  {e['status']:<9} {e['cost']:>7.1f}cr {e['kind']:<8} {e.get('file') or '-'}  :: {e['prompt'][:60]}")
    elif args.cmd == "resume":
        k = key()
        for e in [x for x in ledger.data["entries"] if x["status"] in ("pending", "charged") and x.get("id") and not x.get("file")]:
            task = api("GET", f"/tasks/{e['id']}", k=k)
            if task.get("status") == "success":
                finish(e, task, e["out"], ledger, time.time())
    else:
        run(args.cmd, args.src, args.out, args, ledger)


if __name__ == "__main__":
    main()
