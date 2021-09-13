#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nixUnstable
set -euo pipefail

SYSTEM="${1:-}"

if test -z "$SYSTEM"; then
  echo "USAGE: ${0:-./build.sh} SYSTEM"
  exit 1
fi

nix build --experimental-features "nix-command flakes" ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel"
