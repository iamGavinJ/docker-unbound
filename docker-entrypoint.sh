#!/bin/sh
set -e

rm -f "/var/run/unbound/*.pid"

exec "$@"
