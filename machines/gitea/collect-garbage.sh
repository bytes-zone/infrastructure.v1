#!/usr/bin/env nix-shell
#!nix-shell -i bash
set -euo pipefail

HOST="${1:-}"
if test -z "$HOST"; then
  echo "Usage: ${0:-} HOST"
  exit 1
fi

ssh "$HOST" -- "nix-collect-garbage --delete-older-than 30d"
