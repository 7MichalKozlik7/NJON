#!/bin/bash
set -euo pipefail

echo "[Cleanup] Czyszczenie i konfiguracja systemu..."

# --- Czyszczenie pakietow ---
echo "[Cleanup] Usuwanie niepotrzebnych pakietow..."
sudo apt-get autoremove -y 2>/dev/null || true
sudo apt-get autoclean -y 2>/dev/null || true

echo "[Cleanup] Czyszczenie cache pip..."
pip3 cache purge 2>/dev/null || true

echo "[Cleanup] Aktualny kernel: $(uname -r)"

# --- Aliasy bashrc (idempotentne) ---
BASHRC="${HOME}/.bashrc"
MARKER="# === NJON Jetson Aliases ==="

if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    echo "[Config] Aliasy NJON juz sa w .bashrc - pomijam"
else
    echo "[Config] Dodawanie aliasow do .bashrc..."
    cat >> "$BASHRC" << 'ALIASEOF'

# === NJON Jetson Aliases ===
# GPU & Jetson
alias gpu-info='nvidia-smi'
alias jetson-stats='sudo jtop'
alias jetson-clocks-status='sudo jetson_clocks --show'
alias jetson-mode='sudo nvpmodel -q'

# Ls
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Docker
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dlog='docker logs'

# Jetson info function
jetson-info() {
    echo "=== Jetson System Info ==="
    if [[ -f /proc/device-tree/model ]]; then
        echo "Model: $(tr -d '\0' < /proc/device-tree/model)"
    fi
    dpkg -l nvidia-jetpack 2>/dev/null | awk '/^ii/{print "JetPack: "$3}'
    nvcc --version 2>/dev/null | grep release | awk '{print "CUDA: "$6}' | tr -d ','
    nvpmodel -q 2>/dev/null | grep "NV Power Mode" || true
    echo "Memory: $(free -h | awk '/Mem/{print $3"/"$2}')"
    echo "Disk: $(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
    for tz in /sys/devices/virtual/thermal/thermal_zone*/temp; do
        if [[ -f "$tz" ]]; then
            zone=$(basename "$(dirname "$tz")")
            temp=$(awk '{printf "%.1f", $1/1000}' "$tz")
            echo "Temp ${zone}: ${temp}C"
        fi
    done
}

# Jetson temperature
jetson-temp() {
    for tz in /sys/devices/virtual/thermal/thermal_zone*/temp; do
        if [[ -f "$tz" ]]; then
            zone=$(basename "$(dirname "$tz")")
            temp=$(awk '{printf "%.1f", $1/1000}' "$tz")
            echo "${zone}: ${temp}C"
        fi
    done
}
# === END NJON Aliases ===
ALIASEOF
fi

# --- Skrypt startowy ---
echo "[Config] Tworzenie skryptu startowego..."
sudo tee /usr/local/bin/jetson-startup > /dev/null << 'STARTEOF'
#!/bin/bash
# Jetson startup optimization (NJON)
echo "Applying Jetson optimizations..."
nvpmodel -m 0 2>/dev/null || true
jetson_clocks 2>/dev/null || true
echo "Jetson optimizations applied!"
STARTEOF
sudo chmod +x /usr/local/bin/jetson-startup

# --- Desktop entry ---
DESKTOP_DIR="${HOME}/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cat > "${DESKTOP_DIR}/jetson-monitor.desktop" << DESKEOF
[Desktop Entry]
Name=Jetson Monitor
Comment=Monitor Jetson system stats
Exec=bash -c "command -v jtop >/dev/null && exec sudo jtop || exec htop"
Icon=utilities-system-monitor
Terminal=true
Type=Application
Categories=System;Monitor;
DESKEOF

# --- Raport instalacji ---
echo "[Report] Generowanie raportu instalacji..."
REPORT_FILE="${HOME}/njon_installation_report.txt"
{
    echo "NJON Installation Report"
    echo "Generated: $(date)"
    echo "========================"
    echo
    echo "System Information:"
    echo "------------------"
    uname -a
    if [[ -f /proc/device-tree/model ]]; then
        echo "Model: $(tr -d '\0' < /proc/device-tree/model)"
    fi
    echo

    echo "Installed Components:"
    echo "--------------------"

    # Proste sprawdzenia
    check_tool() {
        local name="$1"
        local cmd="$2"
        if eval "$cmd" &>/dev/null; then
            local ver
            ver=$(eval "$cmd" 2>/dev/null | head -1) || ver="installed"
            echo "  OK: $name ($ver)"
        else
            echo "  BRAK: $name"
        fi
    }

    check_tool "JetPack" "dpkg -l nvidia-jetpack | grep '^ii'"
    check_tool "CUDA" "nvcc --version | grep release"
    check_tool "Docker" "docker --version"
    check_tool "ROS2" "ros2 --version"
    check_tool "Ollama" "ollama --version"

    for mod in torch tensorflow cv2; do
        if python3 -c "import $mod; print(f'$mod v{getattr($mod, \"__version__\", \"ok\")}')" 2>/dev/null; then
            echo "  OK: $mod ($(python3 -c "import $mod; print(getattr($mod, '__version__', 'ok'))" 2>/dev/null))"
        else
            echo "  BRAK: $mod"
        fi
    done

    echo
    echo "Disk Usage:"
    echo "-----------"
    df -h /
    echo
    echo "Memory:"
    echo "-------"
    free -h
} > "$REPORT_FILE"

echo "[Cleanup] OK - Czyszczenie i konfiguracja zakonczona!"
echo "[Report] Raport: $REPORT_FILE"
echo
echo "Przydatne komendy:"
echo "  jetson-info     - Informacje o systemie"
echo "  jetson-stats    - Monitor systemu (jtop)"
echo "  gpu-info        - Status GPU (nvidia-smi)"
echo "  jetson-temp     - Temperatury"
echo "  ml-env          - Aktywacja srodowiska ML"
