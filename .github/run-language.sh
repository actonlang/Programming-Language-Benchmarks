#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:?check or measure}"
language="${2:?language}"
[[ "$mode" == check || "$mode" == measure ]]
toolchain_image="$(python3 -c 'import json,sys; print(json.load(open(".github/languages.json"))[sys.argv[1]].get("image", "mcr.microsoft.com/dotnet/sdk:9.0-noble"))' "$language")"

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
exec 9>"${XDG_STATE_HOME:-$HOME/.local/state}/acton-perf.lock"
flock 9

# Keep benchmark containers in their own storage, so cleanup cannot affect
# other services on the runner.
if ! command -v podman >/dev/null; then
  sudo -n apt-get update
  sudo -n apt-get install -y --no-install-recommends podman containernetworking-plugins catatonit
fi
storage=/var/lib/acton-bench-containers
engine=(sudo -n podman --root "$storage" --runroot /run/acton-bench-containers)
mapfile -t abandoned < <("${engine[@]}" ps --all --quiet 9>&-)
if (( ${#abandoned[@]} )); then
  "${engine[@]}" rm --force "${abandoned[@]}" 9>&-
fi
if [[ -d "$storage" ]] && (( $(sudo -n du -sk "$storage" | cut -f1) > 31457280 )); then
  "${engine[@]}" system prune --all --force 9>&-
fi

image="localhost/acton-bench-${language}:latest"
container="acton-bench-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-${language}"
cleanup() {
  "${engine[@]}" rm --force "$container" 9>&- >/dev/null 2>&1 || true
  "${engine[@]}" image prune --force --filter label=org.actonlang.benchmarks=true 9>&-
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "::group::Prepare $language toolchain"
"${engine[@]}" build --layers --pull=always \
  --build-arg "TOOLCHAIN_IMAGE=$toolchain_image" \
  --build-arg "BENCH_LANGUAGE=$language" --build-arg "BENCH_UID=$(id -u)" \
  --build-arg "BENCH_RUN_ID=${GITHUB_RUN_ID:-$(date -u +%s)}" \
  --tag "$image" .github/containers 9>&-
echo "::endgroup::"

"${engine[@]}" run --rm --init --name "$container" \
  --label org.actonlang.benchmarks=true \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/work" \
  --env "GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-}" \
  --env "GITHUB_SHA=${GITHUB_SHA:-$(git rev-parse HEAD)}" \
  --env "GITHUB_RUN_ID=${GITHUB_RUN_ID:-}" \
  --env "GITHUB_RUN_ATTEMPT=${GITHUB_RUN_ATTEMPT:-}" \
  --env "GITHUB_HEAD_REF=${GITHUB_HEAD_REF:-}" \
  --env "RUNNER_NAME=${RUNNER_NAME:-$(hostname)}" \
  "$image" bash .github/bench.sh "$mode" "$language" 9>&-

"${engine[@]}" image inspect "$image" --format '{{.Id}}' \
  >> "bench/build/environment-${language}.txt" 9>&-
