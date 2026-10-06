#!/usr/bin/env python3
"""ElevenLabs (direct API) voice lines and sound effects with a hard credit budget.

LICENSE GATE: ElevenLabs Terms of Service (non-EEA, updated 2026-03-31) §1(c): free plans are
non-commercial only; paid plans may use the Services commercially. §4(c)(ii): you retain all rights
in your Output. This tool checks the subscription tier via the API and refuses on the free tier.
Only ElevenLabs' own premade voices are used (no community Voice Library voices).

Budget: credits (TTS ~1 credit/character; sound effects ~40 credits/second of audio). The cap and
every generation are recorded in <root>/.atlas/elevenlabs_ledger.json, reconciled against the
account's own usage counter.

API key: $ELEVENLABS_API_KEY or ~/.config/atlas-assets/elevenlabs_key (never printed).

  elevenlabs.py account                       # tier, credits used/limit, local cap
  elevenlabs.py budget set 20000
  elevenlabs.py voices                        # premade voices
  elevenlabs.py voice "Certainly! Here's your slop." -o assets/generated/audio/generate_1.mp3 [--voice <id>]
  elevenlabs.py sfx "short soft keyboard key click" -o assets/generated/sfx/key.mp3 --seconds 0.5
  elevenlabs.py log
"""
import argparse
import datetime as dt
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atlas import Ledger, die, project_root  # noqa: E402

API = "https://api.elevenlabs.io/v1"
KEY_FILE = os.path.expanduser("~/.config/atlas-assets/elevenlabs_key")
DEFAULT_MODEL = "eleven_multilingual_v2"
SFX_CREDITS_PER_SEC = 40.0
SFX_AUTO_CREDITS = 200.0


def key():
    if os.environ.get("ELEVENLABS_API_KEY"):
        return os.environ["ELEVENLABS_API_KEY"].strip()
    if os.path.exists(KEY_FILE):
        with open(KEY_FILE) as f:
            k = f.read().strip()
            if k:
                return k
    die(f"no ElevenLabs API key. Save it to {KEY_FILE} (chmod 600) or set ELEVENLABS_API_KEY.")


class ElevenError(Exception):
    def __init__(self, code, msg):
        super().__init__(msg)
        self.code = code


def call(method, path, body=None, raw=False, timeout=120, retries=6):
    """HTTP call with backoff on rate limits (429). Raises ElevenError on other failures."""
    for attempt in range(retries):
        try:
            return _call(method, path, body, raw, timeout)
        except ElevenError as e:
            if e.code != 429 or attempt == retries - 1:
                raise
            time.sleep(4 * (attempt + 1))


def _call(method, path, body, raw, timeout):
    headers = {"xi-api-key": key(), "User-Agent": "atlas-assets/0.1", "Accept": "*/*"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = r.read()
    except urllib.error.HTTPError as e:
        raise ElevenError(e.code, f"ElevenLabs HTTP {e.code}: {e.read()[:300].decode('utf-8', 'replace')}")
    except urllib.error.URLError as e:
        raise ElevenError(0, f"network error: {e.reason}")
    return payload if raw else json.loads(payload)


def subscription():
    return call("GET", "/user/subscription")


def gate(ledger):
    cached = ledger.data.get("tier_check") or {}
    if cached.get("tier") and time.time() - cached.get("at", 0) < 600:
        sub = {"tier": cached["tier"]}
    else:
        sub = subscription()
        ledger.data["tier_check"] = {"tier": sub.get("tier"), "at": time.time()}
        ledger.save()
    tier = str(sub.get("tier", "")).lower()
    if tier in ("", "free"):
        die(f"license gate: subscription tier is '{tier or 'unknown'}'. Free plans are non-commercial only "
            "(ElevenLabs ToS §1(c)), so these outputs can't ship. Upgrade to a paid plan first.", 3)
    if ledger.cap <= 0:
        die("no ElevenLabs credit cap set. Ask the user, then: elevenlabs.py budget set <credits>", 2)
    return sub


def generate(kind, text, out, args, ledger):
    sub = gate(ledger)
    if kind == "voice":
        cost = float(len(text)) * (0.5 if "flash" in args.model or "turbo" in args.model else 1.0)
        path = f"/text-to-speech/{args.voice}?output_format=mp3_44100_128"
        body = {"text": text, "model_id": args.model,
                "voice_settings": {"stability": args.stability, "similarity_boost": 0.8, "style": args.style, "use_speaker_boost": True}}
    else:
        cost = SFX_CREDITS_PER_SEC * args.seconds if args.seconds else SFX_AUTO_CREDITS
        path = "/sound-generation?output_format=mp3_44100_128"
        body = {"text": text, "prompt_influence": args.influence}
        if args.seconds:
            body["duration_seconds"] = max(0.5, min(30.0, args.seconds))
        if args.loop:
            body["loop"] = True
    entry = {"time": dt.datetime.now().isoformat(timespec="seconds"), "kind": kind, "model": args.model if kind == "voice" else "sound-generation",
             "voice": args.voice if kind == "voice" else None, "prompt": text, "cost": round(cost, 1), "status": "pending",
             "file": None, "out": out, "tier": sub.get("tier"),
             "license": "ElevenLabs ToS §1(c) paid plan commercial use; §4(c)(ii) user retains rights in Output"}
    if not ledger.reserve(entry):
        die(f"budget: ~{cost:.0f} credits needed, only {ledger.remaining():.0f} of {ledger.cap:.0f} left.", 2)
    t0 = time.time()
    try:
        blob = call("POST", path, body, raw=True, timeout=180)
    except ElevenError as e:
        ledger.update(entry, status="rejected", error=str(e)[:200])
        die(f"{e}. Not charged; reservation released.")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    if not out.endswith(".mp3"):
        out = os.path.splitext(out)[0] + ".mp3"
    with open(out, "wb") as f:
        f.write(blob)
    ledger.update(entry, status="done", file=os.path.relpath(out, os.path.dirname(ledger.dir)))
    print(json.dumps({"file": out, "credits_est": round(cost, 1), "seconds": round(time.time() - t0, 1), "kb": len(blob) // 1024}))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("budget")
    b.add_argument("action", nargs="?", choices=["show", "set"], default="show")
    b.add_argument("amount", nargs="?", type=float)
    sub.add_parser("account")
    sub.add_parser("voices")
    sub.add_parser("log")
    v = sub.add_parser("voice")
    v.add_argument("text")
    v.add_argument("-o", "--out", required=True)
    v.add_argument("--voice", default="")
    v.add_argument("--model", default=DEFAULT_MODEL)
    v.add_argument("--stability", type=float, default=0.4)
    v.add_argument("--style", type=float, default=0.35)
    s = sub.add_parser("sfx")
    s.add_argument("text")
    s.add_argument("-o", "--out", required=True)
    s.add_argument("--seconds", type=float, default=0.0, help="0 = let the model decide")
    s.add_argument("--influence", type=float, default=0.4)
    s.add_argument("--loop", action="store_true")
    args = ap.parse_args()
    ledger = Ledger(project_root(args.root), "elevenlabs_ledger")
    if args.cmd == "budget":
        if args.action == "set":
            ledger.data["cap"] = float(args.amount)
            ledger.save()
        print(json.dumps({"cap_credits": ledger.cap, "committed": round(ledger.committed(), 1), "remaining": round(ledger.remaining(), 1)}))
    elif args.cmd == "account":
        s_ = subscription()
        print(json.dumps({"tier": s_.get("tier"), "used": s_.get("character_count"), "limit": s_.get("character_limit"),
                          "resets_unix": s_.get("next_character_count_reset_unix"), "local_cap": ledger.cap,
                          "local_remaining": round(ledger.remaining(), 1)}))
    elif args.cmd == "voices":
        for vv in call("GET", "/voices").get("voices", []):
            if vv.get("category") == "premade":
                labels = vv.get("labels") or {}
                print(f"{vv['voice_id']}  {vv['name']:<12} {labels.get('gender', ''):<7} {labels.get('age', ''):<12} {labels.get('accent', ''):<12} {labels.get('description', labels.get('descriptive', ''))}")
    elif args.cmd == "log":
        for e in ledger.data["entries"][-40:]:
            print(f"{e['time']}  {e['status']:<8} {e['cost']:>7.0f}cr {e['kind']:<6} {e.get('file') or '-'}  :: {e['prompt'][:60]}")
    else:
        if args.cmd == "voice" and not args.voice:
            die("pick a premade voice id with --voice (see: elevenlabs.py voices)")
        generate(args.cmd, args.text, args.out, args, ledger)


if __name__ == "__main__":
    main()
