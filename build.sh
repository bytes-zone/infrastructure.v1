#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-}"

if test -z "$SYSTEM"; then
  echo "USAGE: ${0:-./build.sh} SYSTEM"
  exit 1
fi

nix build ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel"
