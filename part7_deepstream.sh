#!/bin/bash
set -euo pipefail

DS_VERSION="${CFG_DEEPSTREAM_VERSION:-7.1}"

echo "[DeepStream] Instalacja DeepStream ${DS_VERSION}..."

# Sprawdz czy juz zainstalowane
DS_DIR="/opt/nvidia/deepstream/deepstream"
if [[ -d "$DS_DIR" ]]; then
    echo "[DeepStream] DeepStream juz zainstalowane w ${DS_DIR}"
    ls "$DS_DIR"/version* 2>/dev/null || true
    exit 0
fi

# Zaleznosci
echo "[DeepStream] Instalacja zaleznosci..."
sudo apt-get install -y \
    libssl3 libssl-dev \
    libgstreamer1.0-0 gstreamer1.0-tools \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libgstreamer-plugins-base1.0-dev \
    libgstrtspserver-1.0-0 \
    libjansson4 libyaml-cpp-dev libjsoncpp-dev \
    protobuf-compiler libprotobuf-dev

# Pobranie pakietu
DEB_FILE="${HOME}/deepstream-${DS_VERSION}_arm64.deb"
DS_URL="https://developer.nvidia.com/downloads/deepstream-71-71-multiarch"

echo "[DeepStream] Pobieranie pakietu..."
if [[ ! -f "$DEB_FILE" ]]; then
    wget -O "$DEB_FILE" "$DS_URL" || {
        echo "[DeepStream] BLAD: Nie udalo sie pobrac pakietu"
        echo "[DeepStream] URL: $DS_URL"
        exit 1
    }
fi

# Weryfikacja pobranego pliku
if [[ ! -s "$DEB_FILE" ]]; then
    echo "[DeepStream] BLAD: Pobrany plik jest pusty"
    rm -f "$DEB_FILE"
    exit 1
fi

# Instalacja
echo "[DeepStream] Instalacja pakietu deb..."
sudo apt-get install -y "$DEB_FILE"

# Dodatkowe skrypty instalacyjne
if [[ -x /opt/nvidia/deepstream/deepstream/user_additional_install.sh ]]; then
    echo "[DeepStream] Uruchamianie dodatkowej instalacji..."
    sudo /opt/nvidia/deepstream/deepstream/user_additional_install.sh || true
fi

# Cleanup
rm -f "$DEB_FILE"

# Weryfikacja
if [[ -d /opt/nvidia/deepstream/deepstream ]]; then
    echo "[DeepStream] OK - DeepStream zainstalowane."
else
    echo "[DeepStream] BLAD: Katalog DeepStream nie istnieje po instalacji"
    exit 1
fi
