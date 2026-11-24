#!/usr/bin/env python3
"""Generate Strike music + SFX via the Gemini API (Lyria 3, generateContent). Pure stdlib.

Usage:
  python3 -I tools/gen_audio.py --list                      # status per id (no key needed)
  python3 -I tools/gen_audio.py --list-models               # lyria/audio/music models of the key
  python3 -I tools/gen_audio.py --dry-run music_title sfx_shot_starter
  python3 -I tools/gen_audio.py music_title --variants 3    # -> audio/raw/_candidates/mus_title_vN.wav
  python3 -I tools/gen_audio.py music sfx --max-calls 40    # all missing (skips existing files)
  python3 -I tools/gen_audio.py sfx_alert --force --note "shorter, higher"
Selectors: ids, globs ("sfx_pixel_*", "shot_*" matches sfx_shot_*), groups "music" / "sfx" / "all".
Options: --model NAME (override for all), --max-calls N (default 40), --timeout S, --raw DIR.
Models: music -> lyria-3.5. SFX -> lyria-3-clip-preview, falling back to lyria-3.5.

Request (REST):  POST /v1beta/models/<model>:generateContent
  {"contents":[{"role":"user","parts":[{"text": PROMPT}]}],
   "generationConfig":{"responseModalities":["AUDIO","TEXT"]}}
Response: candidates[].content.parts[] with inlineData{mimeType,data(base64)} (mp3 normally; wav, raw PCM
"audio/L16;rate=N", etc. are handled). The audio is converted to 48 kHz 16-bit WAV with afconvert.
On an unexpected response the JSON structure (base64 replaced by byte counts) is written to
audio/raw/.last_response.json.

The API key is read ONLY from env GEMINI_API_KEY (e.g. via `op run --env-file=tools/gemini.env --`).
It is never printed, logged or written. Logs: audio/raw/.gen_log.jsonl.
"""
import argparse, base64, fnmatch, json, os, sys, tempfile, time, wave
import urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # needed under python -I
import audio_common as ac  # noqa: E402

API = "https://generativelanguage.googleapis.com/v1beta"
KEY_ENV = "GEMINI_API_KEY"
MUSIC_MODEL = "lyria-3.5"
SFX_MODELS = ["lyria-3-clip-preview", "lyria-3.5"]


# ------------------------------------------------------------------ http / log
def log(raw_dir, rec):
    os.makedirs(raw_dir, exist_ok=True)
    rec = dict(rec, ts=time.strftime("%Y-%m-%dT%H:%M:%S"))
    with open(os.path.join(raw_dir, ".gen_log.jsonl"), "a") as f:
        f.write(json.dumps(rec) + "\n")


def http(method, url, key, body=None, timeout=300):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("x-goog-api-key", key)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"error": {"message": raw[:300]}}
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        return 0, {"error": {"message": f"network: {type(e).__name__}"}}


def err_msg(resp):
    e = resp.get("error") if isinstance(resp, dict) else None
    return (e or {}).get("message", "") if isinstance(e, dict) else ""


def scrub(o):
    """Copy of a JSON value with base64 payloads replaced by a byte count."""
    if isinstance(o, dict):
        return {k: (f"<{len(v)} base64 chars>" if k == "data" and isinstance(v, str) else scrub(v))
                for k, v in o.items()}
    if isinstance(o, list):
        return [scrub(x) for x in o]
    if isinstance(o, str) and len(o) > 400:
        return o[:400] + f"...<{len(o)} chars>"
    return o


def dump_last(raw_dir, st, resp):
    os.makedirs(raw_dir, exist_ok=True)
    with open(os.path.join(raw_dir, ".last_response.json"), "w") as f:
        json.dump({"http_status": st, "response": scrub(resp)}, f, indent=1)


# ------------------------------------------------------------------ models
def list_models(key, timeout):
    token, shown = None, 0
    while True:
        url = f"{API}/models?pageSize=100" + (f"&pageToken={token}" if token else "")
        st, resp = http("GET", url, key, timeout=timeout)
        if st != 200:
            sys.exit(f"Could not list models (HTTP {st}): {err_msg(resp)}")
        for m in resp.get("models", []):
            n = m.get("name", "")
            if any(w in n.lower() for w in ("lyria", "audio", "music")):
                print(f"{n}  [{', '.join(m.get('supportedGenerationMethods', []))}]  {m.get('description', '')[:70]}")
                shown += 1
        token = resp.get("nextPageToken")
        if not token:
            break
    print(f"{shown} matching models")


# ------------------------------------------------------------------ request / response
def build_prompt(item, note):
    text = item["prompt"]
    if item["group"] == "sfx":
        text += " " + ac.SFX_SUFFIX
    if note:
        text += f"\n\nAdditional correction: {note}"
    return text


def build_body(item, note, modalities):
    return {"contents": [{"role": "user", "parts": [{"text": build_prompt(item, note)}]}],
            "generationConfig": {"responseModalities": modalities}}


def sniff_ext(data, mime):
    m = (mime or "").lower().split(";")[0].strip()
    if data[:4] == b"RIFF":
        return "wav"
    if data[:3] == b"ID3" or data[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"):
        return "mp3"
    if data[:4] == b"OggS":
        return "ogg"
    if data[:4] == b"fLaC":
        return "flac"
    if data[4:8] == b"ftyp":
        return "m4a"
    return {"audio/mpeg": "mp3", "audio/mp3": "mp3", "audio/wav": "wav", "audio/x-wav": "wav",
            "audio/wave": "wav", "audio/mp4": "m4a", "audio/aac": "aac", "audio/ogg": "ogg",
            "audio/flac": "flac"}.get(m, "bin")


def extract_audio(resp):
    """Returns (bytes, mime) of the largest audio inlineData part, or (None, reason)."""
    best = None
    for c in resp.get("candidates", []) or []:
        for p in (c.get("content") or {}).get("parts", []) or []:
            d = p.get("inlineData") or p.get("inline_data")
            if not d or not d.get("data"):
                continue
            mime = str(d.get("mimeType") or d.get("mime_type") or "")
            if not mime.startswith("audio/"):
                continue
            raw = base64.b64decode(d["data"])
            if best is None or len(raw) > len(best[0]):
                best = (raw, mime)
    if best:
        return best
    pf = resp.get("promptFeedback") or {}
    if pf.get("blockReason"):
        return None, f"blocked: {pf['blockReason']}"
    for c in resp.get("candidates", []) or []:
        if c.get("finishReason") not in (None, "STOP"):
            return None, f"finishReason {c['finishReason']}"
    return None, "no audio in response"


def save_as_wav(data, mime, out_wav, raw_dir):
    """Write bytes to a 48 kHz 16-bit WAV at out_wav. Returns (ext, seconds)."""
    os.makedirs(os.path.dirname(out_wav), exist_ok=True)
    mt = (mime or "").lower()
    src_dir = os.path.join(raw_dir, "_src")
    os.makedirs(src_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(out_wav))[0]
    if mt.startswith("audio/l16") or mt.startswith("audio/pcm"):  # raw PCM, rate in mime
        rate = 24000
        for tok in mt.split(";"):
            if tok.strip().startswith("rate="):
                rate = int(tok.split("=")[1])
        src = os.path.join(src_dir, base + ".pcm.wav")
        with wave.open(src, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(data)  # L16 is big-endian per RFC; PCM from Gemini is little-endian
        ext = "pcm"
    else:
        ext = sniff_ext(data, mime)
        src = os.path.join(src_dir, f"{base}.{ext}")
        with open(src, "wb") as f:
            f.write(data)
    ac.to_wav48(src, out_wav)
    return ext, ac.afinfo_duration(out_wav)


# ------------------------------------------------------------------ one generation
class Budget:
    def __init__(self, n):
        self.left, self.used = n, 0

    def take(self):
        if self.left <= 0:
            return False
        self.left -= 1
        self.used += 1
        return True


def post_with_retries(model, body, key, args, budget, item_id, cache):
    st, resp = 0, {}
    for attempt in range(3):
        if not budget.take():
            print(f"  stopped: --max-calls {args.max_calls} reached")
            return "budget", st, resp
        t0 = time.time()
        st, resp = http("POST", f"{API}/models/{model}:generateContent", key, body, args.timeout)
        log(args.raw, {"id": item_id, "model": model, "status": st, "attempt": attempt + 1,
                       "call": budget.used, "sec": round(time.time() - t0, 1),
                       "modalities": body["generationConfig"]["responseModalities"],
                       "error": err_msg(resp)[:200] if st != 200 else ""})
        if st in (429, 500, 502, 503, 504, 0) and attempt < 2:
            wait = 8 * (3 ** attempt)
            print(f"  HTTP {st}, retrying in {wait}s")
            time.sleep(wait)
            continue
        break
    return "done", st, resp


def generate_one(item, out_wav, models, cache, key, args, budget):
    """Returns 'ok', 'fail' or 'budget'."""
    for model in models:
        modalities = cache.get("modalities", ["AUDIO", "TEXT"])
        for _ in range(2):  # second pass: modality fallback
            body = build_body(item, args.note, modalities)
            state, st, resp = post_with_retries(model, body, key, args, budget, item["id"], cache)
            if state == "budget":
                return "budget"
            if st == 400 and modalities != ["AUDIO"] and "modalit" in err_msg(resp).lower():
                print("  API rejected responseModalities [AUDIO,TEXT]; retrying with [AUDIO] (remembered)")
                modalities = ["AUDIO"]
                cache["modalities"] = modalities
                save_cache(args.raw, cache)
                continue
            break
        if st != 200:
            print(f"  {model}: HTTP {st} {err_msg(resp)[:160]}")
            dump_last(args.raw, st, resp)
            if st in (400, 404) and model != models[-1]:
                print(f"  falling back to {models[-1]}")
                continue
            return "fail"
        data, mime = extract_audio(resp)
        if not data:
            print(f"  {model}: {mime}; structure dumped to audio/raw/.last_response.json")
            dump_last(args.raw, st, resp)
            log(args.raw, {"id": item["id"], "model": model, "result": mime})
            if model != models[-1]:
                continue
            return "fail"
        try:
            ext, secs = save_as_wav(data, mime, out_wav, args.raw)
        except Exception as e:
            print(f"  could not convert {mime} ({len(data)} bytes): {e}")
            dump_last(args.raw, st, resp)
            return "fail"
        log(args.raw, {"id": item["id"], "model": model, "mime": mime, "bytes": len(data),
                       "ext": ext, "seconds": round(secs, 2)})
        print(f"  saved {os.path.relpath(out_wav, ac.ROOT)} ({model}, {mime}, {secs:.1f} s)")
        if item["group"] == "sfx":
            cache["sfx_model"] = model
            save_cache(args.raw, cache)
        return "ok"
    return "fail"


def cache_path(raw):
    return os.path.join(raw, ".gen_model")


def load_cache(raw):
    try:
        return json.load(open(cache_path(raw)))
    except Exception:
        return {}


def save_cache(raw, d):
    os.makedirs(raw, exist_ok=True)
    json.dump(d, open(cache_path(raw), "w"), indent=1)


def models_for(item, args, cache):
    if args.model:
        return [args.model]
    if item["group"] == "music":
        return [MUSIC_MODEL]
    first = cache.get("sfx_model")
    return [first] + [m for m in SFX_MODELS if m != first] if first else list(SFX_MODELS)


# ------------------------------------------------------------------ selection
def select(items, sel):
    if not sel:
        return []
    out, seen = [], set()
    for tok in ",".join(sel).split(","):
        tok = tok.strip()
        if not tok:
            continue
        if tok == "all":
            hits = items
        elif tok in ("music", "sfx"):
            hits = [i for i in items if i["group"] == tok]
        else:
            hits = [i for i in items if any(fnmatch.fnmatch(i["id"], p)
                    for p in (tok, "sfx_" + tok, "music_" + tok))]
        if not hits:
            sys.exit(f"No id matches {tok!r}")
        for h in hits:
            if h["id"] not in seen:
                seen.add(h["id"])
                out.append(h)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("select", nargs="*", help="ids, globs, or groups music / sfx / all")
    ap.add_argument("--variants", type=int, default=0, help="N candidates -> _candidates/<file>_vN.wav")
    ap.add_argument("--force", action="store_true", help="overwrite existing outputs")
    ap.add_argument("--note", default="", help="correction appended to the prompt")
    ap.add_argument("--dry-run", action="store_true", help="print request summary, no API call")
    ap.add_argument("--list", action="store_true", help="show status of all ids")
    ap.add_argument("--list-models", action="store_true", help="list lyria/audio/music models")
    ap.add_argument("--model", default="", help="override model for every item")
    ap.add_argument("--max-calls", type=int, default=40)
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--raw", default=ac.RAW, help="raw audio dir (default audio/raw)")
    args = ap.parse_args()

    items = ac.parse_prompts()
    key = os.environ.get(KEY_ENV, "")

    if args.list:
        for it in items:
            p = os.path.join(args.raw, it["file"] + ".wav")
            cand = os.path.join(args.raw, "_candidates")
            nc = len([f for f in os.listdir(cand) if f.startswith(it["file"] + "_v")]) if os.path.isdir(cand) else 0
            st = "present" if os.path.isfile(p) else "missing"
            extra = f"bpm={it['bpm']:g} len={it['length']:g}s" if it["group"] == "music" else f"maxlen={it['maxlen']:g}s"
            print(f"{it['id']:<26} {it['kind']:<7} {st:<8} {extra}" + (f"  candidates={nc}" if nc else ""))
        print(f"{len(items)} ids, {sum(os.path.isfile(os.path.join(args.raw, i['file'] + '.wav')) for i in items)} present")
        return

    if args.list_models:
        if not key:
            sys.exit(f"{KEY_ENV} is not set (use: op run --env-file=tools/gemini.env -- python3 -I tools/gen_audio.py ...)")
        list_models(key, args.timeout)
        return

    chosen = select(items, args.select)
    if not chosen:
        ap.error("give ids / globs / music / sfx / all, or use --list")
    if not key and not args.dry_run:
        sys.exit(f"{KEY_ENV} is not set (use: op run --env-file=tools/gemini.env -- python3 -I tools/gen_audio.py ...)")

    cache = load_cache(args.raw)
    budget = Budget(args.max_calls)
    res = {"ok": [], "fail": [], "skipped": []}
    for it in chosen:
        models = models_for(it, args, cache)
        outs = [os.path.join(args.raw, "_candidates", f"{it['file']}_v{v}.wav") for v in range(1, args.variants + 1)] \
            if args.variants else [os.path.join(args.raw, it["file"] + ".wav")]
        print(f"{it['id']}  [{it['kind']}]  models: {' -> '.join(models)}")
        if args.dry_run:
            body = build_body(it, args.note, cache.get("modalities", ["AUDIO", "TEXT"]))
            text = body["contents"][0]["parts"][0]["text"]
            print(f"  POST {API}/models/{models[0]}:generateContent")
            print(f"  generationConfig: {json.dumps(body['generationConfig'])}")
            print(f"  prompt chars: {len(text)}; calls: {len(outs)}")
            print(f"  would write: {', '.join(os.path.relpath(o, ac.ROOT) for o in outs)}")
            print(f"  prompt head: {text[:110]!r}")
            print(f"  prompt tail: {text[-90:]!r}")
            continue
        status = "ok"
        for out in outs:
            if os.path.isfile(out) and not args.force:
                print(f"  exists, skipping {os.path.relpath(out, ac.ROOT)} (use --force)")
                res["skipped"].append(it["id"])
                continue
            status = generate_one(it, out, models, cache, key, args, budget)
            if status != "ok":
                break
        (res["ok"] if status == "ok" else res["fail"]).append(it["id"])
        if status == "budget":
            break
    if not args.dry_run:
        print(f"done. ok={res['ok']} failed={res['fail']} skipped={sorted(set(res['skipped']))} calls={budget.used}")


if __name__ == "__main__":
    main()
