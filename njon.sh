#!/bin/bash

# NIE UŻYWAMY set -e NA POCZĄTKU BO PRZERYWA SKRYPT!

# Wersja
VERSION="1.0.0"

# Sprawdź opcje linii poleceń
VERBOSE=false
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo "NJON - Jetson Orin AI/ML Installer v$VERSION"
  echo
  echo "Użycie: $0 [opcje]"
  echo
  echo "Opcje:"
  echo "  -h, --help     Wyświetl tę pomoc"
  echo "  -v, --verbose  Tryb szczegółowy (debug)"
  echo "  -V, --version  Wyświetl wersję"
  echo
  echo "Przykłady:"
  echo "  $0             # Uruchom instalator"
  echo "  $0 -v          # Uruchom w trybie debug"
  exit 0
elif [[ "$1" == "-V" ]] || [[ "$1" == "--version" ]]; then
  echo "NJON v$VERSION"
  exit 0
elif [[ "$1" == "-v" ]] || [[ "$1" == "--verbose" ]]; then
  VERBOSE=true
  set -x  # Włącz debug mode
fi

# Funkcja czyszczenia przy wyjściu
cleanup() {
    local exit_code=$?
    echo
    echo -e "\033[91m🛑 Instalacja przerwana!\033[0m"
    if [[ $exit_code -ne 0 ]]; then
        echo -e "\033[91m❌ Kod błędu: $exit_code\033[0m"
    fi
    echo "📝 Log częściowej instalacji: ${LOG_FILE}"
    
    # Usuń trap aby uniknąć rekurencji
    trap - SIGINT SIGTERM EXIT
    exit $exit_code
}

# Sprawdź czy nie uruchomiono jako root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Uwaga: Skrypt uruchomiony jako root (sudo)"
   echo "   Niektóre komponenty mogą wymagać instalacji jako zwykły użytkownik."
   echo "   Zalecane jest uruchomienie bez sudo: ./njon.sh"
   read -p "   Kontynuować mimo to? [y/N]: " -n 1 -r
   echo
   [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")"; pwd)"
PARTS_DIR="${BASE_DIR}/parts"
STATE_FILE="${BASE_DIR}/njon_state"
LOG_FILE="${BASE_DIR}/njon.log"
DETECT_LOG="${BASE_DIR}/njon_detect.log"

mkdir -p "${PARTS_DIR}"
touch "${STATE_FILE}"
touch "${LOG_FILE}"

# Sprawdzenie czy folder parts zawiera skrypty
if [ ! -d "${PARTS_DIR}" ] || [ -z "$(ls -A ${PARTS_DIR}/part*.sh 2>/dev/null)" ]; then
  echo "❌ BŁĄD: Brak skryptów instalacyjnych w folderze '${PARTS_DIR}'"
  echo "   Upewnij się, że wszystkie pliki part*.sh znajdują się w folderze parts/"
  echo
  echo "   Oczekiwana struktura:"
  echo "   njon/"
  echo "   ├── njon.sh"
  echo "   └── parts/"
  echo "       ├── part1_swap.sh"
  echo "       ├── part2_jetpack.sh"
  echo "       └── ..."
  exit 1
fi

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
echo "║                  v1.0.0                        ║"
echo "╚════════════════════════════════════════════════╝"
echo
echo "📅 $(date)"
echo "🖥️  $(uname -n) | $(uname -m)"
echo "💾 Wolne miejsce: $(df -h / | awk 'NR==2 {print $4}')"
echo "⏰ Uptime: $(uptime -p | sed 's/up //')"
echo "🐍 Python: $(python3 --version 2>&1 | awk '{print $2}')"

# Pokaż ostatnią aktualizację jeśli istnieje
if [[ -f "${STATE_FILE}" ]]; then
  LAST_UPDATE=$(grep "^LAST_UPDATE=" "${STATE_FILE}" 2>/dev/null | cut -d'=' -f2-)
  if [[ -n "$LAST_UPDATE" ]]; then
    echo "🕒 Ostatnie sprawdzenie: $LAST_UPDATE"
  fi
fi
echo

# Sprawdzenie miejsca (minimum 20GB zalecane)
check_disk_space 20

# Backup poprzedniego state file jeśli istnieje
if [[ -f "${STATE_FILE}" ]] && [[ -s "${STATE_FILE}" ]]; then
  cp "${STATE_FILE}" "${STATE_FILE}.bak"
fi

# AUTODETEKCJA
echo "🔍 Sprawdzam stan rzeczywisty komponentów..." | tee $DETECT_LOG
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a $DETECT_LOG

for i in $(seq 1 16); do
  printf "[%2d] Sprawdzam: %-40s" "$i" "${PART_NAMES[$i]}" | tee -a $DETECT_LOG
  
  # Wykonaj test BEZ set -e
  if eval "${DETECT_CMDS[$i]}" 2>/dev/null; then
    state="success"
    echo " ✅" | tee -a $DETECT_LOG
  else
    state="missing"
    echo " ❌" | tee -a $DETECT_LOG
  fi
  
  # Aktualizacja stanu
  sed -i "/^PART_${i}=.*$/d" "${STATE_FILE}" 2>/dev/null || true
  echo "PART_${i}=$state" >> "${STATE_FILE}"
done

# Zapisz timestamp ostatniej aktualizacji
sed -i "/^LAST_UPDATE=/d" "${STATE_FILE}" 2>/dev/null || true
echo "LAST_UPDATE=$(date '+%Y-%m-%d %H:%M:%S')" >> "${STATE_FILE}"

echo
echo "╔════════════════════════════════════════════════╗"
echo "║         📊 Status wykrytych komponentów        ║"
echo "╚════════════════════════════════════════════════╝"
echo

for i in $(seq 1 16); do
  state=$(grep "^PART_${i}=" "${STATE_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "missing")
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
for i in $(seq 1 16); do
  state=$(grep "^PART_${i}=" "${STATE_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "missing")
  if [[ "$state" == "missing" ]] || [[ -z "$state" ]]; then
    INSTALL_LIST="$INSTALL_LIST $i"
    ((MISSING_COUNT++))
  fi
done

# GŁÓWNA LOGIKA - ZAWSZE CZEKAJ NA INPUT
if [[ -z $INSTALL_LIST ]]; then
  # Wszystko zainstalowane
  echo "🎉 Wszystkie składniki wykryte jako zainstalowane!"
  echo
  echo "💡 Co chcesz zrobić?"
  echo "   1. Uruchom test środowiska"
  echo "   2. Pokaż status wszystkich komponentów" 
  echo "   3. Wymuś reinstalację komponentu"
  echo "   q. Wyjdź"
  echo
  
  while true; do
    read -p "👉 Wybór: " ACTION
    
    case $ACTION in
      1)
        echo "🚀 Uruchamiam test..."
        python3 ~/test_installation.py || echo "❌ Błąd testu. Sprawdź czy plik istnieje: ~/test_installation.py"
        break
        ;;
      2)
        echo
        echo "📊 Status wszystkich komponentów:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        for i in $(seq 1 16); do
          state=$(grep "^PART_${i}=" "${STATE_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "missing")
          status_icon="❌" 
          [ "$state" == "success" ] && status_icon="✅"
          printf "[%2d] %s %-45s\n" "$i" "$status_icon" "${PART_NAMES[$i]}"
        done
        echo
        echo "Naciśnij Enter aby kontynuować..."
        read
        exec "$0"
        ;;
      3)
        echo
        echo "🔧 Który komponent chcesz przeinstalować? (1-16)"
        read -p "👉 Numer: " REINSTALL_NUM
        if [[ "$REINSTALL_NUM" =~ ^[0-9]+$ ]] && (( REINSTALL_NUM >= 1 && REINSTALL_NUM <= 16 )); then
          sed -i "/^PART_${REINSTALL_NUM}=/d" "${STATE_FILE}"
          echo "PART_${REINSTALL_NUM}=missing" >> "${STATE_FILE}"
          echo "✅ Oznaczono komponent [$REINSTALL_NUM] do reinstalacji"
          echo "🔄 Uruchamiam ponownie..."
          sleep 2
          exec "$0"
        else
          echo "❌ Nieprawidłowy numer"
          continue
        fi
        ;;
      q|Q)
        echo "👋 Do zobaczenia!"
        exit 0
        ;;
      "")
        echo "❌ Nic nie wybrano! Spróbuj ponownie."
        continue
        ;;
      *)
        echo "❌ Nieprawidłowy wybór: $ACTION"
        continue
        ;;
    esac
  done
else
  # Są komponenty do zainstalowania
  echo "📋 Brakujące komponenty ($MISSING_COUNT):"
  echo "   Numery:$INSTALL_LIST"
  echo
  echo "🔧 Opcje instalacji:"
  echo "   • Wpisz numery oddzielone spacją (np. 1 2 3)"
  echo "   • Wpisz 'all' aby zainstalować wszystkie brakujące"
  echo "   • Wpisz 'q' aby wyjść"
  echo

  # Pętla do czasu otrzymania poprawnego inputu
  while true; do
    read -p "👉 Wybór: " PART_SELECTION
    
    # Sprawdzenie czy coś wybrano
    if [[ -z "$PART_SELECTION" ]]; then
      echo "❌ Nic nie wybrano! Spróbuj ponownie."
      echo "💡 Wskazówka: wpisz numery (np. 1 2 3), 'all' lub 'q'"
      continue
    fi
    
    # Obsługa wyjścia
    if [[ "$PART_SELECTION" == "q" || "$PART_SELECTION" == "Q" ]]; then
      echo "👋 Do zobaczenia!"
      exit 0
    fi
    
    # Obsługa 'all'
    if [[ "$PART_SELECTION" == "all" || "$PART_SELECTION" == "ALL" ]]; then
      PART_SELECTION=$INSTALL_LIST
      break
    fi
    
    # Walidacja numerów
    VALID=true
    for num in $PART_SELECTION; do
      if ! [[ "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > 16 )); then
        echo "❌ Błędny numer: $num (dozwolone 1-16)"
        VALID=false
        break
      fi
    done
    
    if [[ "$VALID" == "true" ]]; then
      break
    else
      echo "Spróbuj ponownie..."
    fi
  done

  # Ostrzeżenia przed instalacją
  if [[ "$PART_SELECTION" =~ 5 ]]; then
    echo
    echo "⚠️  UWAGA: OpenCV będzie kompilowany około 3 godzin!"
    read -p "Kontynuować? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && exec "$0"
  fi

  if [[ "$PART_SELECTION" =~ 15 ]]; then
    echo
    echo "⚠️  UWAGA: Migracja na SSD wymaga podłączonego dysku NVMe!"
    echo "   Zostanie użyte urządzenie /dev/nvme0n1"
    read -p "Kontynuować? [Y/n]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Nn]$ ]] && exec "$0"
  fi

  # Instalacja
  echo
  echo "🚀 Rozpoczynam instalację wybranych komponentów..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Ustaw trap tylko na czas instalacji
  trap cleanup SIGINT SIGTERM

  # Teraz włącz set -e tylko dla instalacji
  set -e

  START_TIME=$(date +%s)
  INSTALLED_COUNT=0
  SKIPPED_COUNT=0

  for i in $PART_SELECTION; do
    SCRIPT=$(find "${PARTS_DIR}/" -maxdepth 1 -type f -name "part${i}_*.sh" | head -n1)
    if [[ -z $SCRIPT ]]; then
      echo "⚠️  Skrypt part${i}_*.sh nie znaleziony w ${PARTS_DIR}!"
      echo "   Sprawdź czy plik istnieje i ma poprawną nazwę"
      continue
    fi
    
    # Sprawdź czy skrypt jest wykonywalny
    if [[ ! -x "$SCRIPT" ]]; then
      echo "🔧 Nadaję uprawnienia wykonywania dla $SCRIPT"
      chmod +x "$SCRIPT"
    fi
    
    state=$(grep "^PART_${i}=" "${STATE_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "missing")
    if [[ "$state" == "success" ]]; then
      echo "➡️  [$i] ${PART_NAMES[$i]} już zainstalowane – pomijam."
      ((SKIPPED_COUNT++))
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
      # Aktualizuj timestamp
      sed -i "/^LAST_UPDATE=/d" "${STATE_FILE}" 2>/dev/null || true
      echo "LAST_UPDATE=$(date '+%Y-%m-%d %H:%M:%S')" >> "${STATE_FILE}"
      PART_END=$(date +%s)
      PART_TIME=$((PART_END - PART_START))
      echo "✅ [$i] Zakończono w $(date -d@$PART_TIME -u +%H:%M:%S)"
      ((INSTALLED_COUNT++))
    else
      echo "❌ [$i] Błąd instalacji! Sprawdź log: ${LOG_FILE}"
      exit 1
    fi
  done

  END_TIME=$(date +%s)
  TOTAL_TIME=$((END_TIME - START_TIME))

  # Wyłącz set -e po instalacji
  set +e

  # Usuń trap po zakończeniu instalacji
  trap - SIGINT SIGTERM

  echo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ $INSTALLED_COUNT -eq 0 ]]; then
    echo "ℹ️  Nie zainstalowano żadnych nowych komponentów."
    if [[ $SKIPPED_COUNT -gt 0 ]]; then
      echo "   Pominiętych (już zainstalowanych): $SKIPPED_COUNT"
    fi
  else
    echo "✅ Instalacja zakończona!"
    echo "   Zainstalowanych komponentów: $INSTALLED_COUNT"
    if [[ $SKIPPED_COUNT -gt 0 ]]; then
      echo "   Pominiętych (już zainstalowanych): $SKIPPED_COUNT"
    fi
    echo "⏱️  Całkowity czas: $(date -d@$TOTAL_TIME -u +%H:%M:%S)"
    echo "📝 Log instalacji: ${LOG_FILE}"
    echo
    echo "💡 Następne kroki:"
    echo "   1. source ~/.bashrc (lub zrestartuj terminal)"
    echo "   2. python3 ~/test_installation.py (test środowiska)"
    echo "   3. sudo reboot (zalecane po instalacji)"
  fi

  echo
  echo "🔍 Co chcesz teraz zrobić?"
  echo "   1. Uruchom test środowiska"
  echo "   2. Zobacz ostatnie linie logu"
  echo "   3. Uruchom njon.sh ponownie"
  echo "   q. Zakończ"
  echo
  
  while true; do
    read -p "👉 Wybór: " POST_ACTION

    case $POST_ACTION in
      1)
        echo "🚀 Uruchamiam test..."
        python3 ~/test_installation.py || echo "❌ Błąd testu"
        break
        ;;
      2)
        echo "📜 Ostatnie 20 linii logu:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        tail -n 20 "${LOG_FILE}"
        echo
        echo "Naciśnij Enter aby kontynuować..."
        read
        exec "$0"
        ;;
      3)
        echo "🔄 Uruchamiam ponownie..."
        exec "$0"
        ;;
      q|Q)
        echo "👋 Dziękuję za użycie NJON!"
        exit 0
        ;;
      "")
        echo "❌ Nic nie wybrano! Spróbuj ponownie."
        continue
        ;;
      *)
        echo "❌ Nieprawidłowy wybór: $POST_ACTION"
        continue
        ;;
    esac
  done
fi

echo
echo "👋 Dziękuję za użycie NJON!"
