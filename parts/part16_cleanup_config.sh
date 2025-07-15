#!/bin/bash
set -e
echo "[Cleanup] Czyszczenie i optymalizacja systemu..."

# Czyszczenie pakietów
echo "[Cleanup] Usuwanie niepotrzebnych pakietów..."
sudo apt autoremove -y
sudo apt autoclean -y

# Czyszczenie cache pip
echo "[Cleanup] Czyszczenie cache pip..."
pip3 cache purge || true

# Czyszczenie starych kerneli (zachowujemy tylko aktualny)
echo "[Cleanup] Sprawdzanie starych kerneli..."
CURRENT_KERNEL=$(uname -r)
echo "Aktualny kernel: $CURRENT_KERNEL"

# Konfiguracja bashrc z aliasami pomocniczymi
echo "[Config] Dodawanie przydatnych aliasów..."
cat >> ~/.bashrc << 'EOF'

# NJON Jetson Aliases
alias gpu-info='nvidia-smi'
alias jetson-stats='sudo jtop'
alias jetson-clocks-status='sudo jetson_clocks --show'
alias jetson-mode='sudo nvpmodel -q'
alias jetson-temp='cat /sys/devices/virtual/thermal/thermal_zone*/temp'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlog='docker logs'

# Python virtual env
alias ml-env='source ~/ml-env/bin/activate'

# ROS2 aliases
alias ros2-source='source /opt/ros/humble/setup.bash'
alias ros2-nodes='ros2 node list'
alias ros2-topics='ros2 topic list'

# Function to show Jetson info
jetson-info() {
    echo "=== Jetson System Info ==="
    echo "Model: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
    echo "JetPack: $(dpkg -l nvidia-jetpack | grep ^ii | awk '{print $3}')"
    echo "CUDA: $(nvcc --version | grep release | awk '{print $6}' | cut -c2-)"
    echo "Power Mode: $(sudo nvpmodel -q | grep "NV Power Mode")"
    echo "CPU Temp: $(cat /sys/devices/virtual/thermal/thermal_zone0/temp | awk '{print $1/1000"°C"}')"
    echo "GPU Temp: $(cat /sys/devices/virtual/thermal/thermal_zone1/temp | awk '{print $1/1000"°C"}')"
    echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5")"}')"
}
EOF

# Tworzenie skryptu startowego
echo "[Config] Tworzenie skryptu startowego..."
sudo tee /usr/local/bin/jetson-startup << 'EOF'
#!/bin/bash
# Jetson startup optimization script
echo "Applying Jetson optimizations..."
sudo nvpmodel -m 2  # MAXN mode
sudo jetson_clocks
echo "Jetson optimizations applied!"
EOF
sudo chmod +x /usr/local/bin/jetson-startup

# Utworzenie desktop entry dla monitoringu
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/jetson-monitor.desktop << EOF
[Desktop Entry]
Name=Jetson Monitor
Comment=Monitor Jetson system stats
Exec=gnome-terminal -- bash -c "sudo jtop; exec bash"
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;Monitor;
EOF

# Generowanie raportu instalacji
echo "[Report] Generowanie raportu instalacji..."
REPORT_FILE=~/njon_installation_report.txt
cat > $REPORT_FILE << EOF
NJON Installation Report
Generated: $(date)
========================

System Information:
------------------
$(uname -a)
$(cat /proc/device-tree/model 2>/dev/null || echo "Model: Unknown")

Installed Components:
--------------------
EOF

# Sprawdzenie zainstalowanych komponentów
components=(
    "JetPack|nvidia-jetpack"
    "CUDA|nvcc"
    "Docker|docker"
    "ROS2|ros2"
    "PyTorch|python3 -c 'import torch; print(torch.__version__)'"
    "TensorFlow|python3 -c 'import tensorflow as tf; print(tf.__version__)'"
    "OpenCV|python3 -c 'import cv2; print(cv2.__version__)'"
    "Ollama|ollama"
)

for comp in "${components[@]}"; do
    IFS='|' read -r name cmd <<< "$comp"
    if command -v $cmd &> /dev/null || eval "$cmd" &> /dev/null 2>&1; then
        version=$(eval "$cmd --version 2>/dev/null" || eval "$cmd" 2>/dev/null || echo "installed")
        echo "✓ $name: $version" >> $REPORT_FILE
    else
        echo "✗ $name: not found" >> $REPORT_FILE
    fi
done

echo "" >> $REPORT_FILE
echo "Disk Usage:" >> $REPORT_FILE
df -h >> $REPORT_FILE

echo "[Cleanup] ✅ Czyszczenie i konfiguracja zakończona!"
echo "[Report] 📄 Raport instalacji: $REPORT_FILE"
echo
echo "💡 Przydatne komendy:"
echo "   jetson-info     - Informacje o systemie"
echo "   jetson-stats    - Monitor systemu (jtop)"
echo "   gpu-info        - Status GPU (nvidia-smi)"
echo "   ml-env          - Aktywacja środowiska ML"