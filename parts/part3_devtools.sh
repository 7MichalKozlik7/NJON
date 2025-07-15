#!/bin/bash
set -e
echo "[DevTools] Instalacja narzędzi developerskich"
sudo apt install -y build-essential cmake git wget curl nano htop python3-pip python3-dev python3-venv software-properties-common apt-transport-https ca-certificates gnupg lsb-release
echo "[DevTools] OK"
