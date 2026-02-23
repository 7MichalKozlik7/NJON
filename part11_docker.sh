#!/bin/bash
set -euo pipefail

echo "[Docker] Instalacja Docker + NVIDIA Container Toolkit..."

# --- Docker ---
if command -v docker &>/dev/null; then
    echo "[Docker] Docker juz zainstalowany:"
    docker --version
else
    echo "[Docker] Instalacja Docker..."
    sudo apt-get update
    sudo apt-get install -y docker.io
fi

sudo systemctl enable docker 2>/dev/null || true
sudo systemctl start docker 2>/dev/null || true

# Dodaj uzytkownika do grupy docker
if ! groups "$USER" 2>/dev/null | grep -q docker; then
    echo "[Docker] Dodawanie uzytkownika do grupy docker..."
    sudo usermod -aG docker "$USER" || true
fi

# --- NVIDIA Container Toolkit ---
echo "[Docker] Instalacja NVIDIA Container Toolkit..."

# Klucz GPG (idempotentny)
NVIDIA_KEYRING="/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
if [[ ! -f "$NVIDIA_KEYRING" ]]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o "$NVIDIA_KEYRING"
fi

# Repozytorium
NVIDIA_LIST="/etc/apt/sources.list.d/nvidia-container-toolkit.list"
if [[ ! -f "$NVIDIA_LIST" ]]; then
    distribution=$(. /etc/os-release && echo "${ID}${VERSION_ID}")
    curl -s -L "https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list" | \
        sed "s#deb https://#deb [signed-by=${NVIDIA_KEYRING}] https://#" | \
        sudo tee "$NVIDIA_LIST" > /dev/null
fi

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "[Docker] Restartowanie Docker..."
sudo systemctl restart docker

# Weryfikacja GPU w Docker
echo "[Docker] Test GPU w Docker..."
if sudo docker run --rm --gpus all nvcr.io/nvidia/l4t-base:r36.4.0 nvidia-smi 2>/dev/null; then
    echo "[Docker] OK - NVIDIA Docker dziala!"
else
    echo "[Docker] UWAGA: Test GPU w Docker nie powiodl sie"
    echo "[Docker] Probuje alternatywny obraz..."
    sudo docker run --rm --gpus all ubuntu:22.04 nvidia-smi 2>/dev/null || {
        echo "[Docker] Test GPU nie przeszedl - moze wymagac restartu systemu"
        echo "[Docker] Sprobuj po restarcie: docker run --rm --gpus all ubuntu:22.04 nvidia-smi"
    }
fi
