#!/bin/bash

python3 reproducer.py &
echo $! > /tmp/pid
tail -f /tmp/pid
