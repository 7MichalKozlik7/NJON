#!/bin/bash
set -euo pipefail

SNAPD_REV="${CFG_SNAPD_REVISION:-24724}"

echo "[Snapd] Sprawdzanie i poprawka Snapd..."

# Sprawdz czy snapd zainstalowany
if ! command -v snap &>/dev/null; then
    echo "[Snapd] Instalacja snapd..."
    sudo apt-get update
    sudo apt-get install -y snapd
fi

# Sprawdz aktualna wersje
echo "[Snapd] Aktualna wersja:"
snap version 2>/dev/null || true

# Sprawdz czy poprawka juz zastosowana
if snap list snapd 2>/dev/null | grep -q "$SNAPD_REV"; then
    echo "[Snapd] OK - Wersja ${SNAPD_REV} juz zainstalowana"
    exit 0
fi

# Pobierz i zainstaluj konkretna rewizje
echo "[Snapd] Pobieranie rewizji ${SNAPD_REV}..."
WORK_DIR=$(mktemp -d)
cd "$WORK_DIR"

snap download snapd --revision="$SNAPD_REV" || {
    echo "[Snapd] UWAGA: Nie udalo sie pobrac rewizji ${SNAPD_REV}"
    echo "[Snapd] Kontynuuje z obecna wersja snapd"
    rm -rf "$WORK_DIR"
    exit 0
}

# Znajdz pobrane pliki
SNAP_FILE=$(ls snapd_*.snap 2>/dev/null | head -1)
ASSERT_FILE=$(ls snapd_*.assert 2>/dev/null | head -1)

if [[ -n "$SNAP_FILE" ]] && [[ -n "$ASSERT_FILE" ]]; then
    echo "[Snapd] Instalacja poprawionej wersji..."
    sudo snap ack "$ASSERT_FILE"
    sudo snap install "$SNAP_FILE"

    echo "[Snapd] Zamrazanie wersji snapd..."
    sudo snap refresh --hold snapd || true

    echo "[Snapd] OK - Zainstalowano i zamrozono wersje snapd"
else
    echo "[Snapd] UWAGA: Pliki snap nie zostaly pobrane prawidlowo"
fi

# Cleanup
cd ~
rm -rf "$WORK_DIR"

# Restart serwisow
echo "[Snapd] Restart serwisow..."
sudo systemctl restart snapd.service 2>/dev/null || true
sudo systemctl restart snapd.socket 2>/dev/null || true

# Weryfikacja
echo "[Snapd] Weryfikacja:"
snap version
