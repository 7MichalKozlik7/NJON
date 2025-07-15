#!/bin/bash
set -e
echo "[Snapd] Sprawdzanie i poprawka Snapd..."

# Sprawdzenie czy snapd jest zainstalowany
if ! command -v snap &> /dev/null; then
    echo "[Snapd] Instalacja snapd..."
    sudo apt update
    sudo apt install -y snapd
fi

# Sprawdzenie aktualnej wersji
CURRENT_VERSION=$(snap version | grep snapd | awk '{print $2}')
echo "[Snapd] Aktualna wersja: $CURRENT_VERSION"

# Sprawdzenie czy potrzebna jest poprawka
if snap list snapd 2>/dev/null | grep -q "24724"; then
    echo "[Snapd] ✅ Wersja 24724 już zainstalowana"
    exit 0
fi

# Jeśli występują problemy z snapd na Jetson, aplikujemy poprawkę
echo "[Snapd] Pobieranie stabilnej wersji 24724..."
cd /tmp
snap download snapd --revision=24724

if [ -f snapd_24724.snap ] && [ -f snapd_24724.assert ]; then
    echo "[Snapd] Instalacja poprawionej wersji..."
    sudo snap ack snapd_24724.assert
    sudo snap install snapd_24724.snap
    sudo snap refresh --hold snapd
    
    # Cleanup
    rm -f snapd_24724.snap snapd_24724.assert
    
    echo "[Snapd] ✅ Zainstalowano i zamrożono wersję snapd 24724"
else
    echo "[Snapd] ❌ Błąd pobierania wersji 24724"
    exit 1
fi

# Restart usługi snapd
sudo systemctl restart snapd.service
sudo systemctl restart snapd.socket

echo "[Snapd] Weryfikacja..."
snap version