#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "$0")"; pwd)"
PARTS_DIR="${BASE_DIR}/parts"
STATE_FILE="${BASE_DIR}/njon_state"
LOG_FILE="${BASE_DIR}/njon.log"
DETECT_LOG="${BASE_DIR}/njon_detect.log"

mkdir -p "${PARTS_DIR}"
touch "${STATE_FILE}"
touch "${LOG_FILE}"

declare -A PART_NAMES=(
  [1]="SWAP 16GB"
  [2]="JetPack SDK + CUDA"
  [3]="Narzędzia developerskie"
  [4]="PyTorch, TensorFlow, ONNX"
  [5]="OpenCV 4.10.0 z CUDA (~3h kompilacji)"
  [6]="ROS2 Humble"
  [7]="DeepStream 7.1"
  [8]="Optymalizacja Jetsona"
  [9]="Test i weryfikacja"
  [10]="Ollama (LLM backend)"
  [11]="Docker + NVIDIA Container Toolkit"
  [12]="OpenWebUI (GUI dla LLM, Docker)"
  [13]="Poprawka Snapd"
  [14]="Przeglądarki (chromium, firefox)"
  [15]="Migracja systemu na SSD/NVMe"
  [16]="Czyszczenie i konfiguracja końcowa"
)

declare -A DETECT_CMDS=(
  [1]='swapon --noheadings --show=NAME 2>/dev/null | grep -q "/swapfile"'
  [2]='which nvcc >/dev/null 2>&1 && nvcc --version >/dev/null 2>&1'
  [3]='dpkg -l build-essential 2>/dev/null | grep -q "^ii"'
  [4]='python3 -c "import torch" 2>/dev/null && python3 -c "import tensorflow" 2>/dev/null'
  [5]='python3 -c "import cv2; print(cv2.cuda.getCudaEnabledDeviceCount())" 2>/dev/null | grep -q "[1-9]"'
  [6]='which ros2 >/dev/null 2>&1 && ros2 --version >/dev/null 2>&1'
  [7]='test -d /opt/nvidia/deepstream/deepstream-7.1'
  [8]='nvpmodel -q 2>/dev/null | grep -qE "(MAXN|Mode:2)"'
  [9]='test -f ~/test_installation.py'
  [10]='systemctl is-active --quiet ollama 2>/dev/null'
  [11]='docker --version >/dev/null 2>&1 && docker info 2>/dev/null | grep -q nvidia'
  [12]='docker ps --format "{{.Names}}" 2>/dev/null | grep -q "openwebui"'
  [13]='snap --version >/dev/null 2>&1 && snap list snapd 2>/dev/null | grep -q "24724"'
  [14]='snap list 2>/dev/null | grep -Eq "chromium|firefox"'
  [15]='findmnt / | grep -q nvme0n1'
  [16]='test -f ~/njon_installation_report.txt && grep -q "jetson-info" ~/.bashrc'
)

# Funkcja sprawdzania miejsca na dysku
check_disk_space() {
    local required_gb=$1
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( available_gb < required_gb )); then
        echo "⚠️  UWAGA: Mało miejsca na dysku! Dostępne: ${available_gb}GB, zalecane: ${required_gb}GB"
        read -p "Kontynuować mimo to? [y/N]: " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
}

# Banner
clear
echo
echo "╔════════════════════════════════════════════════╗"
echo "║     🛠️  NJON: Instalator AI/ML dla Jetson Orin ║"
echo "║  📦 JetPack 6.2.1 | CUDA 12.6 | Ubuntu 22.04  ║"
echo "╚════════════════════════════════════════════════╝"
echo
echo "📅 $(date)"
echo "🖥️  $(uname -n) | $(uname -m)"
echo "💾 Wolne miejsce: $(df -h / | awk 'NR==2 {print $4}')"
echo

# Sprawdzenie miejsca (minimum 20GB zalecane)
check_disk_space 20

# AUTODETEKCJA
echo "🔍 Sprawdzam stan rzeczywisty komponentów..." | tee $DETECT_LOG
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a $DETECT_LOG

for i in $(seq 1 16); do
  printf "[%2d] Sprawdzam: %-40s" "$i" "${PART_NAMES[$i]}" | tee -a $DETECT_LOG
  if eval "${DETECT_CMDS[$i]}"; then
    state="success"
    echo " ✅" | tee -a $DETECT_LOG
  else
    state="missing"
    echo " ❌" | tee -a $DETECT_LOG
  fi
  sed -i "/^PART_${i}=.*$/d" "${STATE_FILE}" 2>/dev/null || true
  echo "PART_${i}=$state" >> "${STATE_FILE}"
done

echo
echo "╔════════════════════════════════════════════════╗"
echo "║         📊 Status wykrytych komponentów        ║"
echo "╚════════════════════════════════════════════════╝"
echo

for i in $(seq 1 15); do
  state=$(grep "^PART_${i}=" "${STATE_FILE}" | cut -d'=' -f2)
  status_icon="❌" 
  [ "$state" == "success" ] && status_icon="✅"
  printf "[%2d] %s %-45s" "$i" "$status_icon" "${PART_NAMES[$i]}"
  
  # Dodatkowe informacje dla niektórych komponentów
  case $i in
    5) echo " ⏱️  ~3h kompilacji!" ;;
    15) echo " 💾 Wymaga SSD/NVMe" ;;
    *) echo ;;
  esac
done
echo

# Lista brakujących komponentów
INSTALL_LIST=""
MISSING_COUNT=0
for i in $(seq 1 15); do
  state=$(grep "^PART_${i}=" "${STATE_FILE}" | cut -d'=' -f2)
  if [[ "$state" == "missing" ]]; then
    INSTALL_LIST="$INSTALL_LIST $i"
    ((MISSING_COUNT++))
  fi
done

if [[ -z $INSTALL_LIST ]]; then
  echo "🎉 Wszystkie składniki wykryte jako zainstalowane!"
  echo "💡 Uruchom 'python3 ~/test_installation.py' aby przetestować środowisko"
  exit 0
fi

echo "📋 Brakujące komponenty ($MISSING_COUNT):"
echo "   Numery:$INSTALL_LIST"
echo
echo "🔧 Opcje instalacji:"
echo "   • Wpisz numery oddzielone spacją (np. 1 2 3)"
echo "   • Wpisz 'all' aby zainstalować wszystkie brakujące"
echo "   • Wpisz 'q' aby wyjść"
echo
read -p "👉 Wybór: " PART_SELECTION

# Obsługa wyboru
if [[ "$PART_SELECTION" == "q" || "$PART_SELECTION" == "Q" ]]; then
  echo "👋 Do zobaczenia!"
  exit 0
elif [[ "$PART_SELECTION" == "all" || "$PART_SELECTION" == "ALL" ]]; then
  PART_SELECTION=$INSTALL_LIST
fi

# Walidacja numerów
for num in $PART_SELECTION; do
  if ! [[ "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > 16 )); then
    echo "❌ Błędny numer: $num (dozwolone 1-16)"
    exit 1
  fi
done

# Ostrzeżenia przed instalacją
if [[ "$PART_SELECTION" =~ 5 ]]; then
  echo
  echo "⚠️  UWAGA: OpenCV będzie kompilowany około 3 godzin!"
  read -p "Kontynuować? [Y/n]: " -n 1 -r
  echo
  [[ $REPLY =~ ^[Nn]$ ]] && exit 0
fi

if [[ "$PART_SELECTION" =~ 15 ]]; then
  echo
  echo "⚠️  UWAGA: Migracja na SSD wymaga podłączonego dysku NVMe!"
  echo "   Zostanie użyte urządzenie /dev/nvme0n1"
  read -p "Kontynuować? [Y/n]: " -n 1 -r
  echo
  [[ $REPLY =~ ^[Nn]$ ]] && exit 0
fi

# Instalacja
echo
echo "🚀 Rozpoczynam instalację wybranych komponentów..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

START_TIME=$(date +%s)

for i in $PART_SELECTION; do
  SCRIPT=$(find "${PARTS_DIR}/" -maxdepth 1 -type f -name "part${i}_*.sh" | head -n1)
  if [[ -z $SCRIPT ]]; then
    echo "⚠️  Skrypt part${i} nie znaleziony w ${PARTS_DIR}!"
    continue
  fi
  
  state=$(grep "^PART_${i}=" "${STATE_FILE}" | cut -d'=' -f2)
  if [[ "$state" == "success" ]]; then
    echo "➡️  [$i] ${PART_NAMES[$i]} już zainstalowane – pomijam."
    continue
  fi
  
  echo
  echo "┌────────────────────────────────────────────"
  echo "│ 🔧 [$i] Instaluję: ${PART_NAMES[$i]}"
  echo "└────────────────────────────────────────────"
  
  PART_START=$(date +%s)
  
  if bash "$SCRIPT" 2>&1 | tee -a "${LOG_FILE}"; then
    sed -i "/^PART_${i}=/d" "${STATE_FILE}"
    echo "PART_${i}=success" >> "${STATE_FILE}"
    PART_END=$(date +%s)
    PART_TIME=$((PART_END - PART_START))
    echo "✅ [$i] Zakończono w $(date -d@$PART_TIME -u +%H:%M:%S)"
  else
    echo "❌ [$i] Błąd instalacji! Sprawdź log: ${LOG_FILE}"
    exit 1
  fi
done

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Instalacja zakończona!"
echo "⏱️  Całkowity czas: $(date -d@$TOTAL_TIME -u +%H:%M:%S)"
echo "📝 Log instalacji: ${LOG_FILE}"
echo
echo "💡 Następne kroki:"
echo "   1. source ~/.bashrc (lub zrestartuj terminal)"
echo "   2. python3 ~/test_installation.py (test środowiska)"
echo "   3. sudo reboot (zalecane po instalacji)"
echo