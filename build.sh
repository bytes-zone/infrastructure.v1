#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-}"

if test -z "$SYSTEM"; then
  echo "USAGE: ${0:-./build.sh} SYSTEM"
  exit 1
fi

nix --extra-experimental-features "nix-command flakes" build --print-build-logs ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel"
