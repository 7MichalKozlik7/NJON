#!/bin/bash
set -e
echo "[ROS2] Instalacja ROS2 Humble..."

# Dodanie klucza GPG
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Dodanie repozytorium
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(source /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Aktualizacja i instalacja
sudo apt update
sudo apt install -y \
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

# Inicjalizacja rosdep
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    sudo rosdep init
fi
rosdep update

# Dodanie source do .bashrc jeśli nie istnieje
if ! grep -q '/opt/ros/humble/setup.bash' ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# ROS2 Humble" >> ~/.bashrc
    echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
    echo "export ROS_DOMAIN_ID=0" >> ~/.bashrc
    echo "" >> ~/.bashrc
fi

# Source dla bieżącej sesji
. /opt/ros/humble/setup.bash

# Weryfikacja instalacji
if ros2 --version; then
    echo "[ROS2] ✅ Instalacja zakończona pomyślnie!"
    echo "[ROS2] 💡 Wykonaj 'source ~/.bashrc' w nowym terminalu"
else
    echo "[ROS2] ❌ Błąd weryfikacji instalacji"
    exit 1
fi