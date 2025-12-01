#!/bin/bash

SCRIPT_DIR="$(realpath $(dirname $BASH_SOURCE))"
IPTABLES_BAK="$SCRIPT_DIR/iptables.bak"

if [[ ! -f "$IPTABLES_BAK" ]]; then
  echo "Must have a iptables backup"
  exit 1
fi

CDN="${1:-dl.fedoraproject.org}"
echo "Blocking $CDN"
iptables -F
iptables -A OUTPUT -p tcp -d $CDN -j DROP
iptables -A INPUT -p tcp -s $CDN -j DROP
