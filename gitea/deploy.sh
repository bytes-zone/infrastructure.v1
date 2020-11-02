#!/usr/bin/env nix-shell
#!nix-shell -i bash -p moreutils
set -euo pipefail

HOST="${1:-}"
STORE_PATH="${2:-}"
if test -z "$HOST" || test -z "$STORE_PATH"; then
  echo "Usage: ${0:-} HOST STORE_PATH"
  exit 1
fi
STORE_PATH="$(realpath "$STORE_PATH")"

set -x
nix-copy-closure --use-substitutes --to "$HOST" "$STORE_PATH"
ssh "$HOST" -- "sudo nix-env --profile /nix/var/nix/profiles/system --set ${STORE_PATH}"
ssh "$HOST" -- "sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch"

# collect garbage
ssh "$HOST" -- "nix-collect-garbage --delete-older-than 30d"
