"""Check the publication gate against incomplete or stale results."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('suite', Path(__file__).resolve().parents[2] / '.github/suite.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)


class SuiteTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.results = self.root / 'build/_results/fixture'
        self.results.mkdir(parents=True)
        self.record = dict(lang='fixture', test='sample', code='1.sh', compiler='sh', compilerVersion='1',
            input='small', timeMS=1, cpuInfo='test cpu', runnerName='test runner',
            buildLog={'finished': 'today'}, testLog={'finished': 'today'},
            githubSha='current', githubRunId='123', githubRepository='owner/repo')
        for mock in [patch.object(suite, 'BENCH', self.root),
                     patch.object(suite, 'programs', return_value={'fixture': ('sample', '1.sh', 'sh', '1')}),
                     patch.object(suite, 'PROBLEMS', {'sample': {'tests': [{'input': 'small'}, {'input': 'large'}]}}),
                     patch.dict(os.environ, GITHUB_SHA='current', GITHUB_RUN_ID='123', GITHUB_REPOSITORY='owner/repo')]:
            mock.start()
            self.addCleanup(mock.stop)
        self.write_records()

    def write_records(self):
        for size in ('small', 'large'):
            (self.results / f'fixture_{size}.json').write_text(json.dumps(dict(self.record, input=size)))

    def verify(self):
        with contextlib.redirect_stdout(io.StringIO()):
            return suite.verify('fixture', 'results')

    def test_complete_results_pass(self):
        self.assertEqual(self.verify(), {('test cpu', 'test runner')})

    def test_missing_measurement_fails(self):
        (self.results / 'fixture_large.json').unlink()
        with self.assertRaisesRegex(ValueError, 'missing='):
            self.verify()

    def test_stale_revision_fails(self):
        self.record['githubSha'] = 'old'
        self.write_records()
        with self.assertRaisesRegex(ValueError, 'Wrong githubSha'):
            self.verify()

    def test_timeout_has_no_numeric_measurement(self):
        self.record.update(status='timeout', timeMS=None, timeoutSeconds=120)
        self.write_records()
        self.verify()
        self.record['timeMS'] = 1
        self.write_records()
        with self.assertRaisesRegex(ValueError, 'Invalid timeout'):
            self.verify()

    def test_mixed_machines_fail(self):
        path = self.results / 'fixture_large.json'
        record = json.loads(path.read_text())
        record['runnerName'] = 'another runner'
        path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'different machines'):
            self.verify()

    def test_ignored_build_failure_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Missing build output'):
            suite.verify('fixture', 'build')


if __name__ == '__main__':
    unittest.main()
