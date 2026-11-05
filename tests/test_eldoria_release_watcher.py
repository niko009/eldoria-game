import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import eldoria_release_watcher as watcher


SHA23 = "a" * 40
SHA24 = "b" * 40
REFS = (
    f"{SHA24}\trefs/heads/release/eldoria-v0.5.24\n"
    f"{SHA23}\trefs/heads/release/eldoria-v0.5.23\n"
    f"{'c'*40}\trefs/heads/feature/eldoria-v0.5.25\n"
    f"{'d'*40}\trefs/heads/release/eldoria-v0.5.25;echo-danger\n"
)


class ReleaseWatcherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        folder = Path(self.temp.name)
        self.latest = folder / "latest.json"
        self.server = folder / "server.json"
        self.state = folder / "state.json"
        self.write_version("0.5.22")

    def write_version(self, value):
        self.latest.write_text(json.dumps({"version": value}), encoding="utf8")
        self.server.write_text(json.dumps({"client_version": value}), encoding="utf8")

    def run_once(self, **kw):
        return watcher.run_once(latest=self.latest, server=self.server,
                                state_file=self.state, ls_remote=REFS, **kw)

    def test_only_dedicated_branches_and_semantic_order(self):
        candidate = watcher.choose_branch("0.5.22", REFS)
        self.assertEqual(candidate[1], "0.5.23")
        self.assertEqual(candidate[3], SHA23)
        self.assertEqual(watcher.choose_branch("0.5.24", REFS), None)

    def test_dry_run_never_changes_state_or_production(self):
        self.assertTrue(self.run_once(dry_run=True))
        self.assertFalse(self.state.exists())
        self.assertEqual(watcher.production_version(self.latest, self.server), "0.5.22")

    def test_success_requires_production_version_verification(self):
        def deploy(args, **kwargs):
            self.assertEqual(args[1:], ["0.5.23", "release/eldoria-v0.5.23", "--deploy"])
            self.assertEqual(kwargs["env"]["ELDORIA_EXPECTED_COMMIT"], SHA23)
            self.write_version("0.5.23")
        with patch.object(watcher.os, "geteuid", return_value=0):
            self.assertTrue(self.run_once(executor=deploy))
        self.assertEqual(json.loads(self.state.read_text())["status"], "success")
        self.assertEqual(watcher.choose_branch("0.5.23", REFS)[1], "0.5.24")

    def test_failure_is_latched_until_review(self):
        def bad_release(args, **kwargs):
            raise RuntimeError("build failed")
        with patch.object(watcher.os, "geteuid", return_value=0):
            with self.assertRaisesRegex(RuntimeError, "build failed"):
                self.run_once(executor=bad_release)
            self.assertEqual(json.loads(self.state.read_text())["status"], "failed")
            with self.assertRaisesRegex(RuntimeError, "requires review"):
                self.run_once(executor=bad_release)

    def test_rejects_inconsistent_public_metadata(self):
        self.server.write_text('{"client_version":"0.5.21"}', encoding="utf8")
        with self.assertRaisesRegex(ValueError, "latest.json != server.json"):
            self.run_once(dry_run=True)

    def test_false_success_does_not_record_release(self):
        with patch.object(watcher.os, "geteuid", return_value=0):
            with self.assertRaisesRegex(RuntimeError, "did not advance"):
                self.run_once(executor=lambda args, **kwargs: None)
        self.assertEqual(json.loads(self.state.read_text())["status"], "failed")


if __name__ == "__main__":
    unittest.main()