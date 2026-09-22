#!/usr/bin/env python3
"""Plan the suite and publish verified results from successful languages."""
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

import yaml

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / 'bench'
LANGUAGES = json.loads((ROOT / '.github/languages.json').read_text())
PROBLEMS = {p['name']: p for p in yaml.safe_load((BENCH / 'bench.yaml').read_text())['problems']}
CONFIGS = [(p, yaml.safe_load(p.read_text())) for p in sorted(BENCH.glob('bench_*.yaml'))]


def programs(language):
    selected = LANGUAGES[language]['compilers']
    matched = set()
    result = {}
    for path, config in CONFIGS:
        if config['lang'] != language or not config.get('enabled', True):
            continue
        for env in config.get('environments', []):
            if env['os'] != 'linux' or not env.get('enabled', True):
                continue
            compiler = env['compiler']
            version = str(env['version'])
            choices = set(selected) & {compiler, f'{compiler}:{version}'}
            if not choices:
                continue
            matched.update(choices)
            for problem in config.get('problems', []):
                for source in problem.get('source') or []:
                    name = problem['name']
                    if not (BENCH / 'algorithm' / name / source).is_file():
                        raise ValueError(f'Missing source: {name}/{source}')
                    build_id = re.sub(r'[\\/?]', '_', '_'.join((language, 'linux', compiler, version,
                        env.get('compiler_options_text', 'default'), name, Path(source).stem)))
                    if build_id in result:
                        raise ValueError(f'Duplicate program: {build_id}')
                    result[build_id] = (name, source, compiler, version)
    if set(selected) != matched or not result:
        raise ValueError(f'{language}: compiler selection has no programs: {set(selected) - matched}')
    return result


def verify(language, task):
    expected = programs(language)
    if task in ('build', 'test'):
        for build_id in expected:
            path = BENCH / 'build' / build_id / f'__{task}_output.json'
            if not path.is_file():
                raise ValueError(f'Missing {task} output: {build_id}')
        print(f'{language}: {len(expected)} programs passed {task}')
        return
    expected_records = {}
    for build_id, (problem, source, compiler, version) in expected.items():
        for test in PROBLEMS[problem]['tests']:
            if language in (test.get('exclude_langs') or []):
                continue
            expected_records[f'{build_id}_{test["input"]}.json'] = (problem, source, compiler, version, str(test['input']))
    paths = {p.name: p for p in (BENCH / 'build/_results' / language).glob('*.json')}
    if paths.keys() != expected_records.keys():
        raise ValueError(f'{language}: missing={sorted(expected_records.keys() - paths.keys())}, unexpected={sorted(paths.keys() - expected_records.keys())}')
    machines = set()
    for name, path in paths.items():
        record = json.loads(path.read_text())
        actual = tuple(str(record[k]) for k in ('test', 'code', 'compiler', 'compilerVersion', 'input'))
        if actual != expected_records[name] or record['lang'] != language:
            raise ValueError(f'Wrong program identity: {path}')
        if not record.get('buildLog') or not record.get('testLog'):
            raise ValueError(f'Missing build or correctness evidence: {path}')
        machine = (record.get('cpuInfo'), record.get('runnerName'))
        if not all(machine):
            raise ValueError(f'Missing machine identity: {path}')
        machines.add(machine)
        if record.get('status') == 'timeout':
            if record.get('timeMS') is not None or record.get('timeoutSeconds', 0) <= 0:
                raise ValueError(f'Invalid timeout: {path}')
        elif record.get('status') not in (None, 'ok') or not isinstance(record.get('timeMS'), (int, float)) or not math.isfinite(record['timeMS']) or record['timeMS'] <= 0:
            raise ValueError(f'Invalid measurement: {path}')
        for key, variable in (('githubSha', 'GITHUB_SHA'), ('githubRunId', 'GITHUB_RUN_ID'), ('githubRepository', 'GITHUB_REPOSITORY')):
            if os.environ.get(variable) and str(record.get(key)) != os.environ[variable]:
                raise ValueError(f'Wrong {key}: {path}')
    if len(machines) != 1:
        raise ValueError(f'{language}: measurements came from different machines')
    print(f'{language}: {len(paths)} benchmark records verified')
    return machines


def plan():
    event = os.environ.get('GITHUB_EVENT_NAME', '')
    requested = os.environ.get('REQUESTED_LANGUAGES', '').strip()
    languages = list(LANGUAGES) if not requested or requested == 'all' else requested.replace(',', ' ').split()
    if len(set(languages)) != len(languages) or set(languages) - LANGUAGES.keys():
        raise ValueError('Unknown or repeated language in manual selection')
    measure = event == 'schedule' or (event == 'workflow_dispatch' and os.environ.get('REQUESTED_MODE') == 'measure')
    if measure and os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise ValueError('Measurements must run from main')
    if event in ('pull_request', 'push'):
        base, head = os.environ.get('BASE_SHA', ''), os.environ.get('HEAD_SHA', '')
        if re.fullmatch(r'[0-9a-f]{40}', base) and re.fullmatch(r'[0-9a-f]{40}', head) and set(base) != {'0'}:
            changed = subprocess.check_output(['git', 'diff', '--name-only', base, head], cwd=ROOT, text=True).splitlines()
            affected = set()
            config_languages = {str(path.relative_to(ROOT)): config['lang'] for path, config in CONFIGS}
            source_languages = {}
            for _, config in CONFIGS:
                for problem in config.get('problems', []):
                    for source in problem.get('source') or []:
                        source_languages.setdefault(f'bench/algorithm/{problem["name"]}/{source}', set()).add(config['lang'])
            for path in changed:
                if path in config_languages:
                    affected.add(config_languages[path])
                elif path in source_languages:
                    affected.update(source_languages[path])
                elif path.startswith(('bench/', '.github/')):
                    affected.update(LANGUAGES)
            languages = sorted(affected)
    # GitHub requires a nonempty matrix, even when its job is skipped.
    outputs = {'languages': json.dumps(languages or ['acton']), 'has_work': str(bool(languages)).lower(),
               'measure': str(measure).lower(), 'publish': str(measure and set(languages) == LANGUAGES.keys()).lower()}
    print(json.dumps(outputs))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as out:
            for key, value in outputs.items():
                print(f'{key}={value}', file=out)


def collect_results():
    results = BENCH / 'build/_results'
    available = sorted(p.name for p in results.iterdir() if p.is_dir()) if results.exists() else []
    if set(available) - LANGUAGES.keys():
        raise ValueError(f'Unexpected result languages: {set(available) - LANGUAGES.keys()}')
    if not available:
        raise ValueError('No successful languages to publish')
    machines = set()
    for language in available:
        machines.update(verify(language, 'results'))
    if len(machines) != 1:
        raise ValueError('Results from different machines cannot be published together')
    cpu, runner = next(iter(machines))
    missing = sorted(LANGUAGES.keys() - set(available))
    summary = dict(expectedLanguages=sorted(LANGUAGES), publishedLanguages=available,
        missingLanguages=missing, cpuInfo=cpu, runnerName=runner,
        githubSha=os.environ['GITHUB_SHA'], githubRunId=os.environ['GITHUB_RUN_ID'],
        githubRepository=os.environ['GITHUB_REPOSITORY'])
    (BENCH / 'build/run-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    message = f'Publishing results for {len(available)} of {len(LANGUAGES)} languages.'
    if missing:
        message += f' Unavailable in this run: {", ".join(missing)}.'
    print(message)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as out:
            print(message, file=out)
    return summary


if __name__ == '__main__':
    configured = {config['lang'] for _, config in CONFIGS}
    if LANGUAGES.keys() != configured:
        raise ValueError(f'Language registry mismatch: {configured ^ LANGUAGES.keys()}')
    for language in LANGUAGES:
        programs(language)
    command = sys.argv[1]
    if command == 'plan':
        plan()
    elif command == 'collect-results':
        collect_results()
    elif command == 'list':
        for language in LANGUAGES:
            print(f'{language}: {len(programs(language))} programs')
    elif command.startswith('verify-'):
        machines = set()
        for language in (list(LANGUAGES) if sys.argv[2] == 'all' else [sys.argv[2]]):
            machines.update(verify(language, command[len('verify-'):]) or set())
        if len(machines) > 1:
            raise ValueError('Results from different machines cannot be published together')
    else:
        raise ValueError(f'Unknown command: {command}')
