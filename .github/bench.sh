#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../bench"
mode="${1:?check or measure}"
language="${2:?language}"
[[ "$mode" == check || "$mode" == measure ]]
[[ ! -f /opt/bench-profile ]] || source /opt/bench-profile
mapfile -t compilers < <(python3 -c 'import json,sys; print("\n".join(json.load(open("../.github/languages.json"))[sys.argv[1]]["compilers"]))' "$language")
selection=(--langs "$language" --compilers "${compilers[@]}" --environments linux --no-docker)

mkdir -p build
{
  date --utc --iso-8601=seconds
  uname -a
  lscpu
  cat /etc/os-release
  dotnet --info
} > "build/environment-${language}.txt"

echo "::group::Build $language programs"
dotnet run --no-launch-profile -c Release --project tool -- --task build "${selection[@]}" --force-rebuild
python3 ../.github/suite.py verify-build "$language"
echo "::endgroup::"
echo "::group::Check $language outputs"
dotnet run --no-launch-profile -c Release --project tool -- --task test "${selection[@]}"
python3 ../.github/suite.py verify-test "$language"
echo "::endgroup::"
if [[ "$mode" == measure ]]; then
  echo "::group::Measure $language programs"
  dotnet run --no-launch-profile -c Release --project tool -- --task bench "${selection[@]}"
  python3 ../.github/suite.py verify-results "$language"
  echo "::endgroup::"
fi
