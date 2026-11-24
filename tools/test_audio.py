#!/usr/bin/env python3
"""Self-test for process_audio.py using synthetic WAVs (stdlib only). Run: python3 -I tools/test_audio.py"""
import math, os, shutil, sys, tempfile, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_common as ac  # noqa: E402
import process_audio as pa  # noqa: E402

R = ac.RATE


def tone(freq, sec, amp=0.5):
    return [amp * math.sin(2 * math.pi * freq * i / R) for i in range(int(sec * R))]


def silence(sec):
    return [0.0] * int(sec * R)


class Args:
    music_rms_db = -20.0
    sfx_peak_db = -3.0


def mono(samples):
    return ac.Audio([samples], R)


class Tests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.td, ignore_errors=True)

    def test_trim_silence(self):
        au = mono(silence(0.5) + tone(440, 0.2) + silence(0.5))
        s, e = pa.trim_silence(au)
        self.assertAlmostEqual(s / R, 0.5, delta=0.01)
        self.assertAlmostEqual(e / R, 0.7, delta=0.01)

    def test_sfx_picks_strongest_and_normalizes(self):
        # quiet blip, then a loud blip later: the loud one must win; length <= maxlen
        sig = silence(0.2) + tone(600, 0.1, 0.05) + silence(1.0) + tone(900, 0.5, 0.4) + silence(0.5)
        out = pa.process_sfx(mono(sig), 0.25, -3.0)
        self.assertLessEqual(out.seconds, 0.26)
        self.assertGreater(out.seconds, 0.2)
        self.assertAlmostEqual(ac.db(ac.peak(out)), -3.0, delta=0.1)
        self.assertEqual(out.ch[0][0], 0.0)  # faded in
        self.assertLess(abs(out.ch[0][-1]), 0.01)  # faded out

    def test_silent_clip_raises(self):
        with self.assertRaises(ValueError):
            pa.process_sfx(mono(silence(1.0)), 0.3, -3.0)

    def test_loop_bar_length_and_seam(self):
        bpm = 120  # bar = 2 s
        sig = silence(0.3) + tone(220, 9.0, 0.3)
        # add a 0.5 Hz amplitude wobble that is NOT bar-periodic to make the seam matter
        sig = [s * (0.7 + 0.3 * math.sin(2 * math.pi * 0.37 * i / R)) for i, s in enumerate(sig)]
        out, bars = pa.process_loop(mono(sig), bpm, 6.0, -20.0)
        self.assertEqual(bars, 3)
        self.assertAlmostEqual(out.seconds, 6.0, delta=0.03)  # bar boundary (zero-crossing nudge <= 10 ms)
        self.assertAlmostEqual(ac.db(ac.rms(out)), -20.0, delta=0.5)
        self.assertLess(ac.db(ac.peak(out)), -0.9)
        self.assertLess(pa.seam_ratio(out), 6.0)
        # without the crossfade the seam would jump; confirm crossfade does the work
        raw = mono(sig[int(0.3 * R):int(0.3 * R) + out.n])
        self.assertGreater(abs(raw.ch[0][0] - raw.ch[0][-1]) + 1e-9, 0)

    def test_loop_too_short(self):
        with self.assertRaises(ValueError):
            pa.process_loop(mono(tone(220, 1.0)), 120, 6.0, -20.0)

    def test_normalize_rms_limits_peak(self):
        spiky = [0.0] * 1000 + [1.0] + [0.0] * 1000
        au = pa.normalize_rms(mono(spiky), -6.0, -1.0)
        self.assertLessEqual(ac.db(ac.peak(au)), -0.99)

    @unittest.skipUnless(shutil.which("afconvert"), "afconvert missing (not macOS)")
    def test_convert_and_report_formats(self):
        item_sfx = {"id": "sfx_t", "file": "sfx_t", "kind": "sfx", "group": "sfx", "bpm": 0, "length": 0, "maxlen": 0.3}
        item_loop = {"id": "music_t", "file": "mus_t", "kind": "loop", "group": "music", "bpm": 120, "length": 4, "maxlen": 0}
        raw, out = os.path.join(self.td, "raw"), os.path.join(self.td, "out")
        os.makedirs(raw)
        ac.write_wav(os.path.join(raw, "sfx_t.wav"), mono(silence(0.3) + tone(800, 0.4, 0.8) + silence(0.5)))
        ac.write_wav(os.path.join(raw, "mus_t.wav"), mono(tone(330, 7.0, 0.3)))
        pa.process_item(item_sfx, os.path.join(raw, "sfx_t.wav"), out, Args)
        pa.process_item(item_loop, os.path.join(raw, "mus_t.wav"), out, Args)
        caf, m4a = os.path.join(out, "sfx_t.caf"), os.path.join(out, "mus_t.m4a")
        self.assertTrue(os.path.getsize(caf) > 100 and os.path.getsize(m4a) > 100)
        self.assertAlmostEqual(ac.afinfo_duration(caf), 0.3, delta=0.05)
        self.assertAlmostEqual(ac.afinfo_duration(m4a), 4.0, delta=0.1)
        # decode m4a back and check loudness survived AAC
        dec = os.path.join(self.td, "dec.wav")
        ac.to_wav48(m4a, dec)
        self.assertAlmostEqual(ac.db(ac.rms(ac.read_wav(dec))), -20.0, delta=1.5)
        pa.report([item_sfx, item_loop], out, raw)

    def test_prompt_parsing(self):
        items = ac.parse_prompts()
        ids = [i["id"] for i in items]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(sum(i["group"] == "music" for i in items), 9)
        self.assertGreaterEqual(sum(i["group"] == "sfx" for i in items), 28)
        for i in items:
            if i["kind"] == "loop":
                self.assertGreater(i["bpm"], 0)
            if i["kind"] == "sfx":
                self.assertGreater(i["maxlen"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
