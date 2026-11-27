"""构建快照网络重试：临时中断可重试，权限或冲突不自动重试。"""
import json
import runpy
import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

API = runpy.run_path(str(Path(__file__).with_name("push_build_snapshot.py")))["api"]


class SnapshotRetryTests(unittest.TestCase):
    def test_transient_blob_upload_preserves_exact_payload(self):
        for error in (b"unexpected EOF", b"TLS handshake timeout", b"server GOAWAY"):
            failed = subprocess.CompletedProcess([], 1, b"", error)
            succeeded = subprocess.CompletedProcess([], 0, json.dumps({"sha": "fixed"}).encode(), b"")
            with self.subTest(error=error), patch("subprocess.run", side_effect=[failed, succeeded]) as run, patch("time.sleep"):
                self.assertEqual(API("git/blobs", {"content": "fixed"}), {"sha": "fixed"})
                self.assertEqual(run.call_count, 2)
                self.assertEqual(run.call_args_list[0], run.call_args_list[1])

    def test_permanent_failure_does_not_retry(self):
        failed = subprocess.CompletedProcess([], 1, b"", b"HTTP 403 forbidden")
        with patch("subprocess.run", return_value=failed) as run, patch("time.sleep") as delay:
            with self.assertRaises(RuntimeError):
                API("git/ref/heads/main")
            self.assertEqual(run.call_count, 1)
            delay.assert_not_called()

    def test_retries_are_bounded(self):
        failed = subprocess.CompletedProcess([], 1, b"", b"unexpected EOF")
        with patch("subprocess.run", return_value=failed) as run, patch("time.sleep"):
            with self.assertRaises(RuntimeError):
                API("git/blobs", {"content": "fixed"})
            self.assertEqual(run.call_count, 3)


if __name__ == "__main__":
    unittest.main()
