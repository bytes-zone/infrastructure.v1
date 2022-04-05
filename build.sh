#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-}"

if test -z "$SYSTEM"; then
  echo "USAGE: ${0:-./build.sh} SYSTEM"
  exit 1
fi

set -x
# https://blog.nixbuild.net/posts/2022-03-16-lightning-fast-ci-with-nixbuild-net.html
nix --extra-experimental-features "nix-command flakes" \
    build \
    --print-build-logs \
    --eval-store auto \
    --store ssh-ng://eu.nixbuild.net \
    ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel"
