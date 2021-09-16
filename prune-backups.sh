#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-}"

if test -z "$REPO"; then
  echo "USAGE: ${0:-} some.remote-name.com:repo"
  echo "You can also add additional arguments, e.g. --rsh"
  exit 1
fi

exec borg prune -d 7 -w 4 -m 60 -y 10 "$@"
