#!/bin/bash
set -euo pipefail

POWER_MODE="${CFG_POWER_MODE:-0}"

echo "[Optymalizacja] Konfiguracja trybu zasilania i zegarow..."

# Sprawdz czy narzedzia sa dostepne
if ! command -v nvpmodel &>/dev/null; then
    echo "[Optymalizacja] BLAD: nvpmodel nie znaleziony"
    echo "[Optymalizacja] Czy JetPack jest zainstalowany?"
    exit 1
fi

# Ustaw tryb zasilania
echo "[Optymalizacja] Ustawianie trybu zasilania: mode ${POWER_MODE}..."
sudo nvpmodel -m "$POWER_MODE" || {
    echo "[Optymalizacja] UWAGA: Nie udalo sie ustawic trybu ${POWER_MODE}"
    echo "[Optymalizacja] Probuje tryb MAXN (0)..."
    sudo nvpmodel -m 0 || true
}

# Aktywacja maksymalnych zegarow
echo "[Optymalizacja] Aktywacja jetson_clocks..."
if command -v jetson_clocks &>/dev/null; then
    sudo jetson_clocks || echo "[Optymalizacja] UWAGA: jetson_clocks nie powiodlo sie"
else
    echo "[Optymalizacja] jetson_clocks nie dostepny"
fi

# Weryfikacja
echo "[Optymalizacja] Status:"
sudo nvpmodel -q 2>/dev/null || true
echo
if command -v jetson_clocks &>/dev/null; then
    sudo jetson_clocks --show 2>/dev/null | head -20 || true
fi
echo "[Optymalizacja] OK"
