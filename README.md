# Programming Language Benchmarks

Acton-maintained fork of [hanabi1224/Programming-Language-Benchmarks](https://github.com/hanabi1224/Programming-Language-Benchmarks).

[Published results](https://actonlang.github.io/Programming-Language-Benchmarks/)
compare every upstream language with Acton. Acton implements all 18 problems;
other languages cover the problems for which upstream supplies implementations.

## Measurements

The benchmark workflow builds and checks every selected program before measuring
it. All timings in a published run come from one machine and are collected
sequentially. Each result includes its compiler version, source revision,
CPU information, and Actions run. The downloadable `benchmark-results` artifact
also contains the machine and toolchain inventory and is retained for 90 days.

Full measurements run weekly and on manual dispatch on the dedicated `actest1`
runner (`self-hosted`, `Linux`, `X64`, `perf`). Each language has a separate job;
only one measurement job runs at a time. Pull requests and main pushes check
outputs on hosted runners, selecting affected languages when possible. They do
not collect or publish timings.

Each language uses its own container with the same harness and inputs. The
container runs on the host CPU without a CPU quota. The wrapper holds
`~/.local/state/acton-perf.lock` throughout setup, checking, and measurement.
Other measurements on the host must use that lock. A manual language selection
supports troubleshooting; only a complete run publishes the website. A new full
run cancels an older full run, while normal pushes leave it running.

Container storage is isolated in `/var/lib/acton-bench-containers`. Unused
benchmark containers are removed before each job, dangling images afterwards,
and the image cache is cleared before a build when it exceeds 30 GiB.

`actest1` runs `.github/runner-cleanup.sh` before and after each job, including
jobs from the Acton repository. It removes untracked checkout output after
artifact uploads, clears APT downloads, and resets compiler caches when they
exceed their limits: 8 GiB for Acton, 2 GiB for Zig, and 4 GiB per Rust target
directory. The next job also stops abandoned benchmark containers before clearing
leftovers from an interrupted run.
The hook takes the same performance lock and preserves tracked source files.
Benchmark scratch files live inside the job container and disappear when it exits.

Measurement jobs update the installed hook. For initial setup on `actest1`, copy it to
`/opt/actest1/runner-cleanup.sh` with executable permissions. Set both
`ACTIONS_RUNNER_HOOK_JOB_STARTED` and `ACTIONS_RUNNER_HOOK_JOB_COMPLETED` to that
absolute path in the runner service environment, then restart the idle service.

`.github/languages.json` selects all 39 upstream language entries and their
primary toolchains, including WebAssembly. It does not select every historical
compiler release or experimental backend. `.github/suite.py` requires every
selected program to build, pass correctness checks, and produce every expected
result before publication. A program that passes correctness checks but exceeds
a measurement time limit is shown as a timeout, without timing or memory values.
Crashes and incomplete repetitions fail the job. Toolchain versions, the container image ID, source
revision, and Actions run are recorded with the results.

Native compiler optimizations target the CPU running the benchmark. Acton uses
release optimization and the current tip compiler. Go uses one 1.26 toolchain
throughout the job; dependencies cannot silently select another compiler.

## Running locally

Install .NET 9 and the compilers or runtimes you want to compare. Run commands
from `bench/`, for example:

```sh
# Build and check the Acton implementations.
dotnet run --no-launch-profile -c Release --project tool -- --task build --langs acton
dotnet run --no-launch-profile -c Release --project tool -- --task test --langs acton

# Measure them after their output checks pass.
dotnet run --no-launch-profile -c Release --project tool -- --task bench --langs acton

# Select a particular runtime and problem.
dotnet run --no-launch-profile -c Release --project tool -- --task build --langs python --compilers cpython --problems binarytrees --no-docker
```

`bench/bench.yaml` defines the inputs and expected outputs. Language configurations
are in `bench/bench_*.yaml`. `--no-docker` uses locally installed compilers instead
of the container images in those configurations. On Linux with sudo access, the CI wrapper installs Podman if needed and uses
an isolated container, for example `bash .github/run-language.sh check rust` or
`bash .github/run-language.sh measure rust`.

## Acton implementations

Every problem has an Acton implementation in `bench/algorithm/`. The coroutine
sieve uses a chain of actors with bounded outstanding requests. The HTTP test
runs a local server and concurrent JSON POST clients with up to 64 persistent
connections. secp256k1 uses Acton bigints and Jacobian coordinates, without a
native elliptic-curve library; the Go implementation uses libsecp256k1 through
CGO and is marked as FFI on the site.

The numeric ports reuse buffers and avoid unnecessary permutation copies.
FASTA uses a lookup table for its fixed random-number range, k-nucleotide uses
rolling two-bit keys, and LRU uses a hash table and reusable linked slots.
Regex-redux uses the standard regex library with overlapping ASCII windows
to bound repeated UTF-8 scans. Mandelbrot preserves separate rounding steps
so its bitmap matches the reference on CPUs with fused multiply-add support.
These are starting implementations for further Acton optimization.

## Website

The website is a statically generated Nuxt 2 site. Use Node 22 and pnpm 9.13.2:

```sh
cd website
pnpm install --frozen-lockfile
# Replace the checked-in upstream sample data with local measurements.
pnpm content
NODE_OPTIONS=--openssl-legacy-provider SITE_BASE_PATH=/Programming-Language-Benchmarks/ pnpm build
```

The generated site is in `website/dist`. `SITE_BASE_PATH` defaults to `/` for
local development. All internal links and assets respect the configured prefix.
The checked-in upstream data is only for website development and PR build checks;
publishing replaces it completely with results from the successful benchmark run.

The `bench` workflow measures weekly and on manual dispatch. Its
`publish` job calls `site.yml`, which downloads that run's results, builds the
website on a GitHub-hosted runner, and deploys it to GitHub Pages. Configure the
repository's Pages publishing source as GitHub Actions. A failed build or
measurement job leaves the previous published site in place.

## Attribution

Benchmark problems and many implementations originate from
[The Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/index.html)
and the upstream project. Preserve source-file attribution when adding or
adapting implementations. The repository is distributed under its existing
[MIT license](LICENSE).
