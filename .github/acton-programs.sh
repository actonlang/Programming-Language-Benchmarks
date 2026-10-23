#!/usr/bin/env bash
# Replace the Acton programs (.act files) in bench/algorithm with the programs
# maintained in test/perf-benchgames of the Acton repository, and list each of
# them as a source in bench/bench_acton.yaml and bench/bench_acton_tip.yaml.
# Each problem gets exactly the .act files of its directory there. ACTON_REPO
# and ACTON_REF select the source. ACTON_REF is a tag, a branch or a commit; the
# default is the tip tag, the commit of the published Acton tip build.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
repo="${ACTON_REPO:-https://github.com/actonlang/acton.git}"
ref="${ACTON_REF:-tip}"

source_dir="$(mktemp -d)"
trap 'rm -rf "$source_dir"' EXIT
git init --quiet "$source_dir"
git -C "$source_dir" remote add origin "$repo"
git -C "$source_dir" sparse-checkout set test/perf-benchgames
git -C "$source_dir" fetch --quiet --depth 1 --filter=blob:none origin "$ref"
git -C "$source_dir" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
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

problems="$source_dir/problems.yaml"
echo "problems:" > "$problems"
for problem_dir in "$programs"/*/; do
  problem="$(basename "$problem_dir")"
  theirs=("$problem_dir"*.act)
  (( ${#theirs[@]} )) || continue
  if [[ ! -d "bench/algorithm/$problem" ]] || ! grep -qx "  - name: $problem" bench/bench.yaml; then
    echo "Acton programs without a benchmark problem here: $problem" >&2
    continue
  fi
  rm -f "bench/algorithm/$problem/"*.act
  cp "${theirs[@]}" "bench/algorithm/$problem/"
  printf '  - name: %s\n    source:\n' "$problem" >> "$problems"
  for program in "${theirs[@]}"; do
    printf '      - %s\n' "$(basename "$program")" >> "$problems"
  done
done

# The problems list ends at the next top-level key.
for config in bench/bench_acton.yaml bench/bench_acton_tip.yaml; do
  awk -v problems="$problems" '
    /^problems:/ { while ((getline line < problems) > 0) print line; skipping = 1; next }
    skipping && /^[A-Za-z_]/ { skipping = 0 }
    !skipping { print }
  ' "$config" > "$config.new"
  mv "$config.new" "$config"
done
echo "Acton programs: $repo $ref $commit"
