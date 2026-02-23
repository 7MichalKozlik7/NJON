#!/bin/bash
set -euo pipefail

echo "[DevTools] Instalacja narzedzi developerskich..."

# Lista pakietow
PACKAGES=(
    build-essential
    cmake
    git
    wget
    curl
    nano
    htop
    python3-pip
    python3-dev
    python3-venv
    software-properties-common
    ca-certificates
    gnupg
    lsb-release
    pkg-config
    ninja-build
)

echo "[DevTools] Aktualizacja listy pakietow..."
sudo apt-get update

echo "[DevTools] Instalacja ${#PACKAGES[@]} pakietow..."
sudo apt-get install -y "${PACKAGES[@]}"

# Weryfikacja kluczowych narzedzi
echo "[DevTools] Weryfikacja:"
TOOLS_OK=true
for tool in cmake git python3 pip3; do
    if command -v "$tool" &>/dev/null; then
        VER=$("$tool" --version 2>/dev/null | head -1)
        echo "  OK: $tool - $VER"
    else
        echo "  BRAK: $tool"
        TOOLS_OK=false
    fi
done

if [[ "$TOOLS_OK" == "true" ]]; then
    echo "[DevTools] OK - Wszystkie narzedzia zainstalowane."
else
    echo "[DevTools] UWAGA: Niektore narzedzia nie zostaly zainstalowane."
    exit 1
fi
