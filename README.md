# Programming Language Benchmarks

Acton-maintained fork of [hanabi1224/Programming-Language-Benchmarks](https://github.com/hanabi1224/Programming-Language-Benchmarks).

[Published results](https://actonlang.github.io/Programming-Language-Benchmarks/)
compare Acton with C (Clang), Rust, Go, and CPython. The initial suite covers
hello world, binary trees, Merkle trees, the prime sieve, and the digits of e
and pi. A language appears only where it has an implementation of that problem.
The other upstream implementations remain available for local runs.

## Measurements

The benchmark workflow builds and checks every selected program before measuring
it. All timings in a published run come from one machine and are collected
sequentially. Each result includes its compiler version, source revision,
CPU information, and Actions run. The downloadable `benchmark-results` artifact
also contains the machine and toolchain inventory and is retained for 90 days.

This fork uses the shared `actest1` performance machine through the
`BENCHMARK_RUNNER` repository variable, set to
`["self-hosted", "Linux", "X64", "perf"]`. Only the main branch uses that selection.
Pull requests build and check programs on GitHub-hosted runners and do not
publish measurements. Without the variable, measurements also use hosted runners,
whose hardware can change between runs. Compare languages within the same run.

Use one runner service for repositories sharing the performance machine. The
benchmark script additionally holds `~/.local/state/acton-perf.lock` while
building, checking, and measuring. Other measurements on that host must use the
same lock. New commits cancel superseded runs of this workflow.

The initial suite selection is in `.github/bench.sh`. Rust uses the stable
configuration; `--compilers rustc:stable` excludes the separate nightly entry.
Clang and Rust optimize for the CPU on which the benchmarks run.
Acton uses release optimization and the current `tip` compiler, installed in the
job's temporary directory. The runner's system Acton installation is left intact.
Exact compiler versions are recorded with the results.

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
of the container images in those configurations. On Linux, `.github/bench.sh`
builds and checks the initial suite; `.github/bench.sh measure` also measures it.

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

The `bench` workflow runs on main changes, weekly, and on manual dispatch. Its
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
