#!/usr/bin/env bash
set -euo pipefail

SYSTEM="${1:-}"

if test -z "$SYSTEM"; then
  echo "USAGE: ${0:-./build.sh} SYSTEM"
  exit 1
fi

set -x
# TODO: it'd be really cool to use
# https://blog.nixbuild.net/posts/2022-03-16-lightning-fast-ci-with-nixbuild-net.html
# eventually, but for now it's giving me some trouble copying the built closure
# after the build, so we can't actually do the deploy. It'll probably get stabler
# in the future, and I should try again then.
nix --extra-experimental-features "nix-command flakes" \
    build \
    --print-build-logs \
    ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel"
