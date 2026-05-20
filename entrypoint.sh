#!/usr/bin/env bash
set -e
rsyslogd
sleep 1
exec python3 -u /usr/bin/pssid/pssid-daemon.py "$@"
