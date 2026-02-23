#!/bin/bash
set -euo pipefail

SWAP_SIZE="${CFG_SWAP_SIZE:-16}"
SWAP_FILE="/swapfile"

echo "[SWAP] Konfiguracja ${SWAP_SIZE}GB SWAP..."

# Sprawdz czy swap juz istnieje
if swapon --noheadings --show=NAME 2>/dev/null | grep -q "$SWAP_FILE"; then
    CURRENT_SIZE=$(swapon --noheadings --show=SIZE 2>/dev/null | head -1 | tr -d '[:space:]')
    echo "[SWAP] Swap juz aktywny (rozmiar: ${CURRENT_SIZE}). Pomijam."
    exit 0
fi

# Sprawdz czy plik swap istnieje ale nie jest aktywny
if [[ -f "$SWAP_FILE" ]]; then
    echo "[SWAP] Plik ${SWAP_FILE} istnieje. Usuwam i tworze nowy..."
    sudo swapoff "$SWAP_FILE" 2>/dev/null || true
    sudo rm -f "$SWAP_FILE"
fi

# Sprawdz wolne miejsce
AVAIL_GB=$(df -BG / | awk 'NR==2 {gsub(/G/,"",$4); print $4}')
if (( AVAIL_GB < SWAP_SIZE + 2 )); then
    echo "[SWAP] BLAD: Za malo miejsca! Dostepne: ${AVAIL_GB}GB, wymagane: $((SWAP_SIZE + 2))GB"
    exit 1
fi

# Tworzenie swap file
echo "[SWAP] Tworzenie pliku swap ${SWAP_SIZE}GB..."
if ! sudo fallocate -l "${SWAP_SIZE}G" "$SWAP_FILE" 2>/dev/null; then
    echo "[SWAP] fallocate nie powiodlo sie, uzywam dd..."
    sudo dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$SWAP_SIZE" status=progress
fi

sudo chmod 600 "$SWAP_FILE"
sudo mkswap "$SWAP_FILE"
sudo swapon "$SWAP_FILE"

# Dodaj do fstab jesli nie ma
if ! grep -q "$SWAP_FILE" /etc/fstab 2>/dev/null; then
    echo "${SWAP_FILE} none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# Weryfikacja
if swapon --noheadings --show=NAME 2>/dev/null | grep -q "$SWAP_FILE"; then
    echo "[SWAP] OK - SWAP aktywny:"
    swapon --show
    free -h | grep -i swap
else
    echo "[SWAP] BLAD: Swap nie zostal aktywowany"
    exit 1
fi
