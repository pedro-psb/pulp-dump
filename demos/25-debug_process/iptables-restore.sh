#!/bin/bash

SCRIPT_DIR="$(realpath $(dirname $BASH_SOURCE))"
IPTABLES_BAK="$SCRIPT_DIR/iptables.bak"

if [[ ! -f "$IPTABLES_BAK" ]]; then
  echo "Must have a iptables backup"
  exit 1
fi

iptables-restore < "$IPTABLES_BAK"
