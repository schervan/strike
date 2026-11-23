"""Shared helpers for gen_audio.py / process_audio.py (pure stdlib)."""
import array, math, os, re, subprocess, sys, wave

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PROMPT_FILES = [os.path.join(ROOT, "audio", "prompts", "music.md"),
                os.path.join(ROOT, "audio", "prompts", "sfx.md")]
RAW = os.path.join(ROOT, "audio", "raw")
OUT = os.path.join(ROOT, "Strike", "Resources", "Audio")
RATE = 48000

SFX_SUFFIX = ("Single short sound effect, isolated, dry, no music, no melody, no vocals, no speech, "
              "no background noise, no reverb tail, soft and friendly, not harsh, not loud. "
              "Cartoon video-game style.")


def parse_prompts(paths=None):
    """Returns list of dicts: id, file, kind, bpm, length, maxlen, mood, prompt, group."""
    out = []
    for path in paths or PROMPT_FILES:
        if not os.path.isfile(path):
            continue
        text = open(path, encoding="utf-8").read()
        parts = re.split(r"^## (\S+)\s*$", text, flags=re.M)
        for i in range(1, len(parts), 2):
            pid, body = parts[i], parts[i + 1]
            fields = dict(re.findall(r"^- \*\*([\w/ ]+):\*\*\s*(.*)$", body, flags=re.M))
            blk = re.search(r"```text\n(.*?)\n```", body, flags=re.S)
            if not blk or "File" not in fields:
                continue
            kind = fields.get("Kind", "sfx").strip()
            out.append({"id": pid, "file": fields["File"].strip(), "kind": kind,
                        "group": "sfx" if kind == "sfx" else "music",
                        "bpm": float(fields.get("BPM", 0) or 0),
                        "length": float(fields.get("Length", 0) or 0),
                        "maxlen": float(fields.get("MaxLen", 0) or 0),
                        "mood": fields.get("Mood", ""), "prompt": blk.group(1).strip()})
    return out


# ---------------------------------------------------------------- WAV I/O
class Audio:
    """Float-free 16-bit audio: channels = list of array('h')... stored as lists of float in [-1,1]."""
    def __init__(self, chans, rate=RATE):
        self.ch, self.rate = chans, rate

    @property
    def n(self):
        return len(self.ch[0]) if self.ch else 0

    @property
    def seconds(self):
        return self.n / self.rate


def read_wav(path):
    """Minimal RIFF reader (handles WAVE_FORMAT_EXTENSIBLE, which afconvert emits and wave rejects)."""
    import struct
    data = open(path, "rb").read()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError(f"{path}: not a RIFF/WAVE file")
    pos, fmt, pcm = 12, None, None
    while pos + 8 <= len(data):
        cid, size = data[pos:pos + 4], struct.unpack("<I", data[pos + 4:pos + 8])[0]
        body = data[pos + 8:pos + 8 + size]
        if cid == b"fmt ":
            fmt = struct.unpack("<HHIIHH", body[:16])
        elif cid == b"data":
            pcm = body
        pos += 8 + size + (size & 1)
    if fmt is None or pcm is None:
        raise ValueError(f"{path}: missing fmt/data chunk")
    tag, nch, rate, _, _, bits = fmt
    if bits != 16 or tag not in (1, 0xFFFE):
        raise ValueError(f"{path}: only 16-bit PCM supported (tag {tag}, {bits} bit)")
    a = array.array("h")
    a.frombytes(pcm[:len(pcm) // 2 * 2])
    if sys.byteorder == "big":
        a.byteswap()
    chans = [[s / 32768.0 for s in a[c::nch]] for c in range(nch)]
    return Audio(chans, rate)


def write_wav(path, au):
    nch = len(au.ch)
    a = array.array("h", [0]) * (au.n * nch)
    for c, data in enumerate(au.ch):
        a[c::nch] = array.array("h", [max(-32768, min(32767, int(round(s * 32767)))) for s in data])
    if sys.byteorder == "big":
        a.byteswap()
    with wave.open(path, "wb") as w:
        w.setnchannels(nch)
        w.setsampwidth(2)
        w.setframerate(au.rate)
        w.writeframes(a.tobytes())


def run(cmd):
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"{cmd[0]} failed: {(r.stderr or r.stdout).strip()[:300]}")
    return r.stdout


def afconvert(src, dst, fmt, data):
    """fmt e.g. 'WAVE', data e.g. 'LEI16@48000'."""
    run(["afconvert", "-f", fmt, "-d", data, src, dst])


def to_wav48(src, dst):
    afconvert(src, dst, "WAVE", f"LEI16@{RATE}")


def afinfo_duration(path):
    out = run(["afinfo", path])
    m = re.search(r"estimated duration:\s*([\d.]+)", out)
    return float(m.group(1)) if m else 0.0


# ---------------------------------------------------------------- measures
def peak(au):
    return max((max(map(abs, c)) if c else 0.0) for c in au.ch) if au.ch else 0.0


def rms(au):
    tot, cnt = 0.0, 0
    for c in au.ch:
        tot += sum(s * s for s in c)
        cnt += len(c)
    return math.sqrt(tot / cnt) if cnt else 0.0


def db(x):
    return 20 * math.log10(x) if x > 1e-9 else -180.0


def frame_env(au, ms=5):
    """Max |sample| per frame across channels."""
    f = max(1, int(au.rate * ms / 1000))
    env = []
    for i in range(0, au.n, f):
        env.append(max(max(map(abs, c[i:i + f]), default=0.0) for c in au.ch))
    return env, f
