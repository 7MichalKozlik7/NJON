#!/bin/bash
set -euo pipefail

echo "[JetPack] Instalacja JetPack SDK i CUDA..."

# Sprawdz czy juz zainstalowane
if command -v nvcc &>/dev/null; then
    NVCC_VER=$(nvcc --version 2>/dev/null | grep "release" | awk '{print $6}' | tr -d ',')
    echo "[JetPack] nvcc juz zainstalowane (wersja: ${NVCC_VER})"
    echo "[JetPack] Sprawdzam sciezki CUDA..."
else
    echo "[JetPack] Aktualizacja systemu..."
    sudo apt-get update
    sudo apt-get upgrade -y

    echo "[JetPack] Instalacja pakietu nvidia-jetpack..."
    sudo apt-get install -y nvidia-jetpack
fi

# Dodaj sciezki CUDA do .bashrc (idempotentnie)
BASHRC="${HOME}/.bashrc"
CUDA_PATH_LINE='export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}'
CUDA_LD_LINE='export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}'

if ! grep -qF 'cuda/bin' "$BASHRC" 2>/dev/null; then
    {
        echo ""
        echo "# CUDA paths (added by NJON)"
        echo "$CUDA_PATH_LINE"
        echo "$CUDA_LD_LINE"
    } >> "$BASHRC"
    echo "[JetPack] Dodano sciezki CUDA do .bashrc"
else
    echo "[JetPack] Sciezki CUDA juz sa w .bashrc"
fi

# Ustaw sciezki w biezacej sesji
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

# Weryfikacja
if command -v nvcc &>/dev/null; then
    echo "[JetPack] Weryfikacja:"
    nvcc --version
    echo "[JetPack] OK - JetPack i CUDA zainstalowane."
else
    echo "[JetPack] BLAD: nvcc nie znaleziony po instalacji!"
    echo "[JetPack] Sprawdz czy /usr/local/cuda/bin/nvcc istnieje"
    exit 1
fi
