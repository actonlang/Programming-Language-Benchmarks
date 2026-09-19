"""Exercise measurement failures through the real benchmark command."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


BENCH = Path(__file__).resolve().parents[1]
TOOL = BENCH / "tool/bin/Release/net9/BenchTool.dll"


class MeasurementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(
            ["dotnet", "build", "-c", "Release", str(BENCH / "tool")],
            check=True,
        )

    def measure(self, script, repeat=1, timeout=5, trivial=False):
        with tempfile.TemporaryDirectory(prefix="bench-measurement-") as directory:
            root = Path(directory)
            (root / "algorithm").mkdir()
            (root / "include").mkdir()
            build = root / "build/fixture_linux_sh_test_default_sample_fixture"
            build.mkdir(parents=True)
            (build / "fixture.sh").write_text(script)
            (root / "bench.yaml").write_text(f"""
problems:
  - name: sample
    trivial: {str(trivial).lower()}
    tests:
      - input: 1
        repeat: {repeat}
        timeout_seconds: {timeout}
langs:
  - lang: fixture
    problems:
      - name: sample
        source: [fixture.sh]
    environments:
      - os: linux
        compiler: sh
        version: test
        run_cmd: /bin/sh fixture.sh
        runtime_included: false
""")
            env = os.environ.copy()
            env.pop("GITHUB_HEAD_REF", None)
            result = subprocess.run(
                ["dotnet", str(TOOL), "--task", "bench", "--no-docker", "--fail-fast"],
                cwd=root, env=env, text=True, capture_output=True, timeout=30,
            )
            records = [json.loads(p.read_text()) for p in (root / "build/_results").rglob("*.json")]
            return result, records

    def test_success_publishes_a_measurement(self):
        result, records = self.measure("sleep 0.02\nexit 0\n")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(records), 1)
        self.assertGreater(records[0]["timeMS"], 0)

    def test_nonzero_exit_never_publishes(self):
        for trivial in (False, True):
            with self.subTest(trivial=trivial):
                result, records = self.measure("exit 7\n", trivial=trivial)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(records, [])
                self.assertIn("Benchmark exited with code 7", result.stdout + result.stderr)

    def test_timeout_never_publishes(self):
        result, records = self.measure("sleep 2\n", timeout=1)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(records, [])

    def test_incomplete_repeats_never_publish(self):
        result, records = self.measure(
            "if [ -f ran ]; then exit 7; fi\ntouch ran\nexit 0\n", repeat=2,
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(records, [])
        self.assertIn("1/2", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
