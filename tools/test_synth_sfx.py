#!/usr/bin/env python3
"""Tests for synth_sfx.py. Run: python3 -I tools/test_synth_sfx.py"""
import os, sys, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_common as ac  # noqa: E402
import synth_sfx as ss  # noqa: E402

ITEMS = [i for i in ac.parse_prompts() if i["group"] == "sfx"]


class T(unittest.TestCase):
    def test_every_id_has_recipe_and_vice_versa(self):
        self.assertGreaterEqual(len(ITEMS), 28)
        self.assertEqual(set(i["id"] for i in ITEMS), set(ss.RECIPES))

    def test_specs(self):
        for it in ITEMS:
            d = ss.synth(it["id"], it["maxlen"])
            sec = len(d) / ac.RATE
            with self.subTest(id=it["id"]):
                self.assertGreaterEqual(sec, 0.04)
                self.assertLessEqual(sec, it["maxlen"] + 1e-6)
                pk = max(map(abs, d))
                self.assertLessEqual(ac.db(pk), -2.99)
                self.assertGreater(ac.db(pk), -3.2)  # normalized, not silent
                self.assertLess(abs(sum(d) / len(d)), 0.01)  # no DC offset
                self.assertLess(abs(d[0]), 0.05)
                self.assertLess(abs(d[-1]), 0.05)

    def test_deterministic(self):
        for it in ITEMS:
            self.assertEqual(ss.synth(it["id"], it["maxlen"]), ss.synth(it["id"], it["maxlen"]), it["id"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
