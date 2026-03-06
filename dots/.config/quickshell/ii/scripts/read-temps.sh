#!/bin/bash
# CPU: k10temp Tctl
sensors | awk '/Tctl/ { gsub(/[^0-9.]/,"",$2); print "cpu=" $2 }'
# GPU: Nvidia
echo "gpu=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null)"
