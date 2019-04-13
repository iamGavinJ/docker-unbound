#!/bin/sh
set -e

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export AMBER='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

export CONFIG='/usr/local/etc/unbound'

mountpoint -q ${CONFIG} && printf "${GREEN}[INFO] ${CONFIG} is mounted on container${NC}\n" || printf "${RED}[WARN] ${CONFIG} is not mounted on container${NC}\n"
rm -f "/var/run/unbound/*.pid"

exec "$@"
