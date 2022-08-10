#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-}"

if test -z "$SYSTEM"; then
  echo "USAGE: ${0:-./build.sh} SYSTEM"
  exit 1
fi

# https://blog.nixbuild.net/posts/2022-03-16-lightning-fast-ci-with-nixbuild-net.html
set -x
OUTPUT="$(
  nix --extra-experimental-features "nix-command flakes" \
      build \
      --json \
      --eval-store auto \
      --store ssh-ng://eu.nixbuild.net \
      --print-build-logs \
      ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel" 
)"

OUT="$(jq -r '.[0]'.outputs.out <<< "$OUTPUT")"

nix-copy-closure --use-substitutes --from eu.nixbuild.net "$OUT"
echo "$OUT"
