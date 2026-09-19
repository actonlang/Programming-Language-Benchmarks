#!/usr/bin/env bash
set -euo pipefail

# Keep the benchmark compiler separate from the runner's installed Acton.
install_dir="${RUNNER_TEMP:?}/benchmark-acton"
mkdir -p "$install_dir"
curl --fail --location --retry 3 \
  https://github.com/actonlang/acton/releases/download/tip/acton-linux-x86_64-tip.tar.xz \
  --output "$install_dir/acton.tar.xz"
tar -xf "$install_dir/acton.tar.xz" -C "$install_dir" --strip-components=1
echo "$install_dir/bin" >> "${GITHUB_PATH:?}"
"$install_dir/bin/acton" version
