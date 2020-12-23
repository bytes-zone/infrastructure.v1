#!/usr/bin/env bash
set -euo pipefail

SSH_HOST="${1:-}"
VHOST="${2:-}"

if test -z "$SSH_HOST"; then
  echo "Usage: ${0:-} SSH_HOST VHOST"
  exit 1
elif test -z "$VHOST"; then
  echo "Usage: ${0:-} ${SSH_HOST} VHOST"
  echo "(vhost was missing)"
  exit 1
fi

ssh "$SSH_HOST" "grep -e '^${VHOST}:' /var/log/nginx/access.log | goaccess --log-format=VCOMBINED -" > report.html
open report.html
