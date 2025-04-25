#!/bin/bash

SCRIPT_DIR="$(realpath $(dirname $BASH_SOURCE))"
IPTABLES_BAK="$SCRIPT_DIR/iptables.bak"
iptables-save > "$IPTABLES_BAK"
