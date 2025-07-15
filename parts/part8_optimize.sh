#!/bin/bash
set -e
echo "[Optymalizacja] Tryb MAXN SUPER, zegary"
sudo nvpmodel -m 2
sudo jetson_clocks
sudo nvpmodel -q
sudo jetson_clocks --show
