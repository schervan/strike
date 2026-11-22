#!/usr/bin/env python3
"""Generate Strike art via the Gemini API from art/prompts/gemini/PROMPTS.md (pure stdlib).

Usage:
  python3 tools/gen_art.py --list                      # status per prompt (no key needed)
  python3 tools/gen_art.py --dry-run 1 15              # payload summary only (no key needed)
  python3 tools/gen_art.py 1 --variants 4              # 4 candidates -> art/raw/_candidates/hero_vN.png
  python3 tools/gen_art.py 2-35                        # generate the rest (skips existing files)
  python3 tools/gen_art.py 7 --force --note "background must be flat green"
Selectors: numbers, ranges, comma lists ("2-6,9"). Options: --model NAME, --max-calls N (60),
--timeout S (120), --raw DIR.

The API key is read ONLY from env GEMINI_API_KEY. It is never printed, logged or written.
Logs (no key, no image data): art/raw/.gen_log.jsonl. Chosen model cache: art/raw/.gen_model.
"""
import argparse, base64, io, json, os, re, site, sys, time
import urllib.error, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PROMPTS = os.path.join(ROOT, "art", "prompts", "gemini", "PROMPTS.md")
RAW = os.path.join(ROOT, "art", "raw")
API = "https://generativelanguage.googleapis.com/v1beta"
KEY_ENV = "GEMINI_API_KEY"


# ------------------------------------------------------------------ parsing
def parse_prompts(path=PROMPTS):
    text = open(path, encoding="utf-8").read()
    parts = re.split(r"^## #(\d+)\s+(.*)$", text, flags=re.M)
    out = []
    for i in range(1, len(parts), 3):
        n, title, body = int(parts[i]), parts[i + 1].strip(), parts[i + 2]
        save = re.search(r"\*\*Save as:\*\*\s*`([^`]+)`", body)
        att = re.search(r"\*\*Attach:\*\*\s*(.*)", body)
        img = re.search(r"\*\*Image:\*\*\s*(.*)", body)
        blk = re.search(r"```text\n(.*?)\n```", body, flags=re.S)
        if not (save and blk):
            continue
        save_rel = save.group(1)
        attach = re.findall(r"art/raw/[\w\-./]+?\.png", att.group(1)) if att else []
        prompt = "\n".join(l for l in blk.group(1).split("\n")
                           if not l.strip().lower().startswith("output file name:")).strip()
        wide = bool(img and ("16:9" in img.group(1) or "wide" in img.group(1).lower()))
        out.append({"n": n, "title": title, "save": save_rel,
                    "sheet": os.path.splitext(os.path.basename(save_rel))[0],
                    "attach": attach, "aspect": "16:9" if wide else "1:1", "prompt": prompt})
    return out


def parse_selection(args):
    nums = []
    for a in args:
        for tok in a.split(","):
            tok = tok.strip()
            if not tok:
                continue
            m = re.fullmatch(r"(\d+)-(\d+)", tok)
            if m:
                nums += list(range(int(m.group(1)), int(m.group(2)) + 1))
            elif tok.isdigit():
                nums.append(int(tok))
            else:
                sys.exit(f"Bad selector: {tok!r}")
    return nums


# ------------------------------------------------------------------ helpers
def raw_path(rel, raw_dir):
    # rel looks like art/raw/x.png ; honour --raw override
    return os.path.join(raw_dir, os.path.relpath(rel, "art/raw"))


def model_cache_path(raw_dir):
    return os.path.join(raw_dir, ".gen_model")


def load_cache(raw_dir):
    try:
        return json.load(open(model_cache_path(raw_dir)))
    except Exception:
        return {}


def save_cache(raw_dir, d):
    os.makedirs(raw_dir, exist_ok=True)
    json.dump(d, open(model_cache_path(raw_dir), "w"), indent=1)


def log(raw_dir, rec):
    os.makedirs(raw_dir, exist_ok=True)
    rec = dict(rec, ts=time.strftime("%Y-%m-%dT%H:%M:%S"))
    with open(os.path.join(raw_dir, ".gen_log.jsonl"), "a") as f:
        f.write(json.dumps(rec) + "\n")


def http(method, url, key, body=None, timeout=120):
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


def version_key(name):
    nums = re.findall(r"\d+(?:\.\d+)?", name)
    ver = tuple(float(x) for x in nums[:2]) if nums else (0.0,)
    return (ver, "exp" not in name)


def pick_model(key, timeout):
    names, token = [], None
    while True:
        url = f"{API}/models?pageSize=100" + (f"&pageToken={token}" if token else "")
        st, resp = http("GET", url, key, timeout=timeout)
        if st != 200:
            sys.exit(f"Could not list models (HTTP {st}): {err_msg(resp)}")
        for m in resp.get("models", []):
            n = m.get("name", "").replace("models/", "")
            if "image" in n and "generateContent" in m.get("supportedGenerationMethods", []):
                names.append(n)
        token = resp.get("nextPageToken")
        if not token:
            break
    if not names:
        sys.exit("No image-capable model with generateContent found for this key. Use --model.")
    return max(names, key=version_key)


def build_body(item, attach_files, note, with_image_config=True):
    text = item["prompt"] + (f"\n\nAdditional correction: {note}" if note else "")
    parts = [{"text": text}]
    for p in attach_files:
        parts.append({"inline_data": {"mime_type": "image/png",
                                      "data": base64.b64encode(open(p, "rb").read()).decode()}})
    gc = {"responseModalities": ["IMAGE"]}
    if with_image_config:
        gc["imageConfig"] = {"aspectRatio": item["aspect"]}
    return {"contents": [{"role": "user", "parts": parts}], "generationConfig": gc}


def extract_image(resp):
    for c in resp.get("candidates", []) or []:
        for p in (c.get("content") or {}).get("parts", []) or []:
            d = p.get("inlineData") or p.get("inline_data")
            if d and d.get("data") and str(d.get("mimeType") or d.get("mime_type") or "image/").startswith("image/"):
                return base64.b64decode(d["data"])
    return None


def no_image_reason(resp):
    pf = resp.get("promptFeedback") or {}
    if pf.get("blockReason"):
        return f"blocked: {pf['blockReason']}"
    for c in resp.get("candidates", []) or []:
        if c.get("finishReason") not in (None, "STOP"):
            return f"finishReason {c['finishReason']}"
    return "no image in response"


def to_png(data):
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return data
    try:
        from PIL import Image
    except ImportError:
        sys.path.append(site.getusersitepackages())
        try:
            from PIL import Image
        except ImportError:
            print("  warning: image is not PNG and Pillow is missing; saving raw bytes as .png")
            return data
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


# ------------------------------------------------------------------ main
class Budget:
    def __init__(self, n):
        self.left, self.used = n, 0

    def take(self):
        if self.left <= 0:
            return False
        self.left -= 1
        self.used += 1
        return True


def generate_one(item, out_path, model, cache, key, args, attach_files, budget):
    """Returns 'ok', 'fail' or 'budget'."""
    use_cfg = not cache.get("no_image_config", False)
    for attempt_cfg in (0, 1):
        body = build_body(item, attach_files, args.note, use_cfg)
        resp, st = {}, 0
        for attempt in range(3):
            if not budget.take():
                print(f"  stopped: --max-calls {args.max_calls} reached")
                return "budget"
            st, resp = http("POST", f"{API}/models/{model}:generateContent", key, body, args.timeout)
            log(args.raw, {"n": item["n"], "model": model, "status": st, "attempt": attempt + 1,
                           "call": budget.used, "imageConfig": use_cfg,
                           "error": err_msg(resp)[:200] if st != 200 else ""})
            if st in (429, 500, 502, 503, 504, 0) and attempt < 2:
                wait = 5 * (3 ** attempt)
                print(f"  HTTP {st}, retrying in {wait}s")
                time.sleep(wait)
                continue
            break
        if st == 400 and use_cfg and "imageconfig" in err_msg(resp).lower().replace("_", ""):
            print("  API rejected imageConfig; retrying without it (remembered)")
            cache["no_image_config"] = True
            save_cache(args.raw, cache)
            use_cfg = False
            continue
        break
    if st != 200:
        print(f"  failed: HTTP {st} {err_msg(resp)[:160]}")
        return "fail"
    data = extract_image(resp)
    if not data:
        reason = no_image_reason(resp)
        print(f"  failed: {reason}")
        log(args.raw, {"n": item["n"], "result": reason})
        return "fail"
    data = to_png(data)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(data)
    print(f"  saved {os.path.relpath(out_path, ROOT)} ({len(data)//1024} KB)")
    return "ok"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("select", nargs="*", help="prompt numbers / ranges, e.g. 1 2-35 3,5")
    ap.add_argument("--variants", type=int, default=0, help="N candidates -> _candidates/<sheet>_vN.png")
    ap.add_argument("--force", action="store_true", help="overwrite existing outputs")
    ap.add_argument("--note", default="", help="correction appended to the prompt")
    ap.add_argument("--dry-run", action="store_true", help="print payload summary, no API call")
    ap.add_argument("--list", action="store_true", help="show status of all prompts")
    ap.add_argument("--model", default="", help="override model name")
    ap.add_argument("--max-calls", type=int, default=60)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--raw", default=RAW, help="raw art dir (default art/raw)")
    args = ap.parse_args()

    items = parse_prompts()
    by_n = {i["n"]: i for i in items}

    if args.list:
        for it in items:
            p = raw_path(it["save"], args.raw)
            cand = os.path.join(args.raw, "_candidates")
            nc = len([f for f in os.listdir(cand) if f.startswith(it["sheet"] + "_v")]) if os.path.isdir(cand) else 0
            st = "present" if os.path.isfile(p) else "missing"
            print(f"#{it['n']:<2} {it['sheet']:<24} {st:<8} {it['aspect']:<5} "
                  f"attach={','.join(os.path.basename(a) for a in it['attach']) or '-'}"
                  + (f"  candidates={nc}" if nc else ""))
        print(f"{len(items)} prompts, "
              f"{sum(os.path.isfile(raw_path(i['save'], args.raw)) for i in items)} present")
        return

    nums = parse_selection(args.select)
    if not nums:
        ap.error("give prompt numbers (e.g. 1 or 2-35), or use --list")
    for n in nums:
        if n not in by_n:
            sys.exit(f"No prompt #{n}")

    key = os.environ.get(KEY_ENV, "")
    if not key and not args.dry_run:
        sys.exit(f"{KEY_ENV} is not set. Create a key at aistudio.google.com, add\n"
                 f'  export {KEY_ENV}="..."\nto ~/.zshrc and restart the shell / Claude Code.')

    cache = load_cache(args.raw)
    model = args.model or cache.get("model", "")
    if not model:
        if args.dry_run:
            model = "(auto-pick at run time via GET /v1beta/models)"
        else:
            model = pick_model(key, args.timeout)
            cache["model"] = model
            save_cache(args.raw, cache)
    print(f"model: {model}")

    budget = Budget(args.max_calls)
    results = {"ok": [], "fail": [], "skipped": []}
    for n in nums:
        it = by_n[n]
        files = [raw_path(a, args.raw) for a in it["attach"]]
        missing = [os.path.basename(f) for f in files if not os.path.isfile(f)]
        count = args.variants or 1
        outs = []
        for v in range(1, count + 1):
            if args.variants:
                outs.append(os.path.join(args.raw, "_candidates", f"{it['sheet']}_v{v}.png"))
            else:
                outs.append(raw_path(it["save"], args.raw))
        print(f"#{n} {it['title']}  [{it['aspect']}]  attach: "
              f"{', '.join(os.path.basename(f) for f in files) or 'none'}")
        if args.dry_run:
            body = build_body(it, [f for f in files if os.path.isfile(f)], args.note,
                              not cache.get("no_image_config", False))
            parts = body["contents"][0]["parts"]
            print(f"  prompt chars: {len(parts[0]['text'])}; inline images: {len(parts) - 1}"
                  + (f"; MISSING attachments (would skip): {', '.join(missing)}" if missing else ""))
            print(f"  generationConfig: {json.dumps(body['generationConfig'])}")
            print(f"  would write: {', '.join(os.path.relpath(o, ROOT) for o in outs)}")
            print(f"  prompt head: {parts[0]['text'][:110]!r}")
            print(f"  prompt tail: {parts[0]['text'][-90:]!r}")
            continue
        if missing:
            print(f"  skipped: missing attachment(s) {', '.join(missing)}")
            results["skipped"].append(n)
            continue
        status = "ok"
        for out in outs:
            if os.path.isfile(out) and not args.force:
                print(f"  exists, skipping {os.path.relpath(out, ROOT)} (use --force)")
                results["skipped"].append(n)
                continue
            status = generate_one(it, out, model, cache, key, args, files, budget)
            if status != "ok":
                break
        if status == "ok":
            results["ok"].append(n)
        elif status == "fail":
            results["fail"].append(n)
        else:
            results["fail"].append(n)
            break
    if not args.dry_run:
        print(f"done. ok={results['ok']} failed={results['fail']} skipped={sorted(set(results['skipped']))} "
              f"calls={budget.used}")


if __name__ == "__main__":
    main()
