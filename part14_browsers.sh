#!/bin/bash
set -euo pipefail

echo "[Browsers] Instalacja przegladarek..."

# Sprawdz czy snap jest dostepny
if ! command -v snap &>/dev/null; then
    echo "[Browsers] UWAGA: snap nie jest dostepny"
    echo "[Browsers] Probuje instalacje przez apt..."

    sudo apt-get update

    echo "[Browsers] Instalacja Firefox z apt..."
    sudo apt-get install -y firefox 2>/dev/null || \
        echo "[Browsers] Firefox nie dostepny przez apt"

    echo "[Browsers] Instalacja Chromium z apt..."
    sudo apt-get install -y chromium-browser 2>/dev/null || \
        echo "[Browsers] Chromium nie dostepny przez apt"
else
    # Chromium
    if snap list chromium &>/dev/null; then
        echo "[Browsers] Chromium juz zainstalowany"
    else
        echo "[Browsers] Instalacja Chromium..."
        sudo snap install chromium || echo "[Browsers] UWAGA: Chromium nie zainstalowany"
    fi

    # Firefox
    if snap list firefox &>/dev/null; then
        echo "[Browsers] Firefox juz zainstalowany"
    else
        echo "[Browsers] Instalacja Firefox..."
        sudo snap install firefox || echo "[Browsers] UWAGA: Firefox nie zainstalowany"
    fi
fi

# Weryfikacja
echo "[Browsers] Zainstalowane przegladarki:"
command -v chromium &>/dev/null && echo "  OK: chromium" || \
    command -v chromium-browser &>/dev/null && echo "  OK: chromium-browser" || \
    snap list chromium 2>/dev/null | grep -q chromium && echo "  OK: chromium (snap)" || \
    echo "  BRAK: chromium"

command -v firefox &>/dev/null && echo "  OK: firefox" || \
    snap list firefox 2>/dev/null | grep -q firefox && echo "  OK: firefox (snap)" || \
    echo "  BRAK: firefox"

echo "[Browsers] Instalacja zakonczona."
