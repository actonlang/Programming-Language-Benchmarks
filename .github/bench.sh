#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../bench"
export TMPDIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"

# Build, check, and measure exactly the same selection on one machine.
selection=(
  --langs acton c rust go python
  --compilers acton clang rustc:stable go cpython
  --problems helloworld binarytrees merkletrees nsieve edigits pidigits
  --no-docker --fail-fast
)

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
exec 9>"${XDG_STATE_HOME:-$HOME/.local/state}/acton-perf.lock"
flock 9

dotnet run --no-launch-profile -c Release --project tool -- --task build "${selection[@]}" --force-rebuild
dotnet run --no-launch-profile -c Release --project tool -- --task test "${selection[@]}"
if [[ "${1:-}" == "measure" ]]; then
  dotnet run --no-launch-profile -c Release --project tool -- --task bench "${selection[@]}"
fi
