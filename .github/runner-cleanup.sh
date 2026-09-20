#!/usr/bin/env bash
# Install outside the checkout as both job hooks on actest1.
set -euo pipefail

workspace="${GITHUB_WORKSPACE:?}"
case "$workspace" in
  /home/kll/actions-runner/_work/acton/acton|\
  /home/kll/actions-runner/_work/Programming-Language-Benchmarks/Programming-Language-Benchmarks)
    ;;
  *) echo "Refusing to clean an unexpected workspace: $workspace" >&2; exit 1 ;;
esac

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
exec 9>"${XDG_STATE_HOME:-$HOME/.local/state}/acton-perf.lock"
flock --wait 120 9

# Stop containers left by an interrupted job before touching their checkout.
if command -v podman >/dev/null && [[ -d /var/lib/acton-bench-containers ]]; then
  engine=(sudo -n podman --root /var/lib/acton-bench-containers --runroot /run/acton-bench-containers)
  mapfile -t abandoned < <("${engine[@]}" ps --all --quiet 9>&-)
  if (( ${#abandoned[@]} )); then
    timeout 120 "${engine[@]}" rm --force "${abandoned[@]}" 9>&-
  fi
fi

if [[ -d "$workspace/.git" ]]; then
  [[ "$(realpath "$workspace")" == "$workspace" ]]
  timeout 120 git -C "$workspace" clean -ffdx
fi

# apt-get retains downloads, including every installed Acton tip package.
if ! timeout 120 sudo -n apt-get clean; then
  echo "::warning::Could not clear the APT download cache."
fi

# Retain useful compiler caches between jobs, but bound their disk usage.
trim_cache() {
  local directory="$1" limit_kib="$2" size_kib
  [[ -d "$directory" && ! -L "$directory" ]] || return 0
  size_kib="$(du -sk "$directory" | cut -f1)"
  if (( size_kib > limit_kib )); then
    echo "Clearing oversized compiler cache: $directory (${size_kib} KiB)"
    timeout 120 find "$directory" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  fi
}
trim_cache /home/kll/.cache/acton 8388608
trim_cache /home/kll/.cache/zig 2097152
trim_cache /tmp/rs/target 4194304
trim_cache /tmp/rsn/target 4194304

df -h /home/kll/actions-runner
