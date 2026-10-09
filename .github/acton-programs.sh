#!/usr/bin/env bash
# Replace the Acton programs (.act files) in bench/algorithm with the programs
# maintained in test/perf-benchgames of the Acton repository. Each problem gets
# exactly the .act files of its directory there. ACTON_REPO and ACTON_REF select
# the source; the default is the commit of the published Acton tip build.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
repo="${ACTON_REPO:-https://github.com/actonlang/acton.git}"
ref="${ACTON_REF:-tip}"

source_dir="$(mktemp -d)"
trap 'rm -rf "$source_dir"' EXIT
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$ref" --filter=blob:none --sparse "$repo" "$source_dir"
git -C "$source_dir" sparse-checkout set test/perf-benchgames
commit="$(git -C "$source_dir" rev-parse HEAD)"
programs="$source_dir/test/perf-benchgames"

missing=()
for problem_dir in bench/algorithm/*/; do
  problem="$(basename "$problem_dir")"
  ours=("$problem_dir"*.act)
  theirs=("$programs/$problem/"*.act)
  if (( ${#ours[@]} > 0 && ${#theirs[@]} == 0 )); then
    missing+=("$problem")
  fi
done
if (( ${#missing[@]} )); then
  echo "Acton programs missing from $repo at $ref ($commit): ${missing[*]}" >&2
  exit 1
fi
for problem_dir in "$programs"/*/; do
  problem="$(basename "$problem_dir")"
  theirs=("$problem_dir"*.act)
  (( ${#theirs[@]} )) || continue
  if [[ -d "bench/algorithm/$problem" ]]; then
    rm -f "bench/algorithm/$problem/"*.act
    cp "${theirs[@]}" "bench/algorithm/$problem/"
  else
    echo "Acton programs without a benchmark problem here: $problem" >&2
  fi
done
echo "Acton programs: $repo $ref $commit"
