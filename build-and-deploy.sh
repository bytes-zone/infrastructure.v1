#!/usr/bin/env bash
set -euo pipefail

BUILD_TARGET="${1:-}"
DEPLOY_TARGET="${2:-}"

if test -z "$BUILD_TARGET" || test -z "$DEPLOY_TARGET"; then
  echo "USAGE: ${0:-} BUILD_TARGET DEPLOY_TARGET"
  exit 1
fi

set -x
STORE_PATH="$(./build.sh "$BUILD_TARGET")"
./deploy.sh "$DEPLOY_TARGET" "$STORE_PATH"
