#!/bin/bash
set -e
echo "[SWAP] Tworzę 16GB SWAP..."
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
swapon --show
free -h
echo "[SWAP] SWAP aktywny."
