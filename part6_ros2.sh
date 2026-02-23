#!/bin/bash
set -euo pipefail

ROS_DOMAIN="${CFG_ROS_DOMAIN_ID:-0}"

echo "[ROS2] Instalacja ROS2 Humble..."

# Sprawdz czy juz zainstalowane
if command -v ros2 &>/dev/null; then
    echo "[ROS2] ROS2 juz zainstalowane:"
    ros2 --version 2>/dev/null || true
    echo "[ROS2] Sprawdzam konfiguracje..."
fi

# Klucz GPG (idempotentny)
KEYRING="/usr/share/keyrings/ros-archive-keyring.gpg"
if [[ ! -f "$KEYRING" ]]; then
    echo "[ROS2] Dodawanie klucza GPG..."
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o "$KEYRING"
else
    echo "[ROS2] Klucz GPG juz istnieje"
fi

# Repozytorium (idempotentny)
ROS_LIST="/etc/apt/sources.list.d/ros2.list"
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-jammy}")

if [[ ! -f "$ROS_LIST" ]]; then
    echo "[ROS2] Dodawanie repozytorium..."
    echo "deb [arch=${ARCH} signed-by=${KEYRING}] http://packages.ros.org/ros2/ubuntu ${CODENAME} main" | \
        sudo tee "$ROS_LIST" > /dev/null
else
    echo "[ROS2] Repozytorium juz skonfigurowane"
fi

# Instalacja
echo "[ROS2] Aktualizacja i instalacja pakietow..."
sudo apt-get update
sudo apt-get install -y \
    ros-humble-desktop \
    ros-humble-navigation2 \
    ros-humble-nav2-bringup \
    ros-humble-slam-toolbox \
    ros-humble-robot-localization \
    python3-rosdep \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    python3-colcon-common-extensions

# Inicjalizacja rosdep (idempotentny)
if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
    echo "[ROS2] Inicjalizacja rosdep..."
    sudo rosdep init
fi
rosdep update || true

# Dodanie do .bashrc (idempotentny)
BASHRC="${HOME}/.bashrc"
if ! grep -qF '/opt/ros/humble/setup.bash' "$BASHRC" 2>/dev/null; then
    {
        echo ""
        echo "# ROS2 Humble (added by NJON)"
        echo "source /opt/ros/humble/setup.bash"
        echo "export ROS_DOMAIN_ID=${ROS_DOMAIN}"
    } >> "$BASHRC"
    echo "[ROS2] Dodano source ROS2 do .bashrc (DOMAIN_ID=${ROS_DOMAIN})"
else
    echo "[ROS2] Source ROS2 juz w .bashrc"
fi

# Source dla biezacej sesji
if [[ -f /opt/ros/humble/setup.bash ]]; then
    . /opt/ros/humble/setup.bash
fi

# Weryfikacja
echo "[ROS2] Weryfikacja..."
if command -v ros2 &>/dev/null; then
    ros2 --version
    echo "[ROS2] OK - Instalacja zakonczona!"
else
    echo "[ROS2] BLAD: ros2 nie znaleziony po instalacji"
    exit 1
fi
