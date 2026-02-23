#!/bin/bash

# NJON - Jetson Orin AI/ML Installer
# Kompletny instalator z konfiguracją i zbieraniem parametrów
# Wersja 2.0.0

VERSION="2.0.0"

# --- KOLORY I FORMATOWANIE ---
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
CYAN='\033[96m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- OPCJE LINII POLECEN ---
VERBOSE=false
NONINTERACTIVE=false
CONFIG_FILE=""

print_help() {
    echo "NJON - Jetson Orin AI/ML Installer v$VERSION"
    echo
    echo "Uzycie: $0 [opcje]"
    echo
    echo "Opcje:"
    echo "  -h, --help          Wyswietl te pomoc"
    echo "  -v, --verbose       Tryb szczegolowy (debug)"
    echo "  -V, --version       Wyswietl wersje"
    echo "  -c, --config FILE   Uzyj pliku konfiguracyjnego"
    echo "  -y, --yes           Tryb nieinteraktywny (domyslne wartosci)"
    echo
    echo "Przyklady:"
    echo "  $0                  # Uruchom instalator interaktywnie"
    echo "  $0 -v               # Uruchom w trybie debug"
    echo "  $0 -c my.conf       # Uzyj konfiguracji z pliku"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) print_help ;;
        -V|--version) echo "NJON v$VERSION"; exit 0 ;;
        -v|--verbose) VERBOSE=true; set -x; shift ;;
        -c|--config) CONFIG_FILE="$2"; shift 2 ;;
        -y|--yes) NONINTERACTIVE=true; shift ;;
        *) echo "Nieznana opcja: $1"; echo "Uzyj -h aby zobaczyc pomoc"; exit 1 ;;
    esac
done

# --- SCIEZKI ---
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PARTS_DIR="${BASE_DIR}/parts"
STATE_FILE="${BASE_DIR}/njon_state"
LOG_FILE="${BASE_DIR}/njon.log"
DETECT_LOG="${BASE_DIR}/njon_detect.log"
NJON_CONFIG="${BASE_DIR}/njon.conf"

# --- FUNKCJE POMOCNICZE ---

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "${LOG_FILE}"
}

print_msg() {
    echo -e "${BLUE}[NJON]${NC} $*"
}

print_ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

print_err() {
    echo -e "${RED}[BLAD]${NC} $*"
}

print_warn() {
    echo -e "${YELLOW}[UWAGA]${NC} $*"
}

# Formatowanie czasu (przenośne - nie wymaga GNU date -d@)
format_time() {
    local total_seconds=$1
    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}

# Bezpieczna aktualizacja state file (atomowa)
update_state() {
    local key="$1"
    local value="$2"
    local tmpfile="${STATE_FILE}.tmp"

    # Usun stary wpis i dodaj nowy
    grep -v "^${key}=" "${STATE_FILE}" 2>/dev/null > "$tmpfile" || true
    echo "${key}=${value}" >> "$tmpfile"
    mv "$tmpfile" "${STATE_FILE}"
}

# Odczyt wartosci ze state file
get_state() {
    local key="$1"
    local default="$2"
    local val
    val=$(grep "^${key}=" "${STATE_FILE}" 2>/dev/null | tail -1 | cut -d'=' -f2-)
    echo "${val:-$default}"
}

# Odczyt wartosci z config
get_config() {
    local key="$1"
    local default="$2"
    local val
    val=$(grep "^${key}=" "${NJON_CONFIG}" 2>/dev/null | tail -1 | cut -d'=' -f2-)
    echo "${val:-$default}"
}

# Zapytanie usera z domyslna wartoscia
ask_user() {
    local prompt="$1"
    local default="$2"
    local varname="$3"

    if [[ "$NONINTERACTIVE" == "true" ]]; then
        eval "$varname=\"$default\""
        return
    fi

    local display_default=""
    [[ -n "$default" ]] && display_default=" [${default}]"

    read -rp "$(echo -e "${CYAN}?${NC}") ${prompt}${display_default}: " user_input
    if [[ -z "$user_input" ]]; then
        eval "$varname=\"$default\""
    else
        eval "$varname=\"$user_input\""
    fi
}

# Zapytanie tak/nie
ask_yn() {
    local prompt="$1"
    local default="$2" # Y lub N

    if [[ "$NONINTERACTIVE" == "true" ]]; then
        [[ "$default" == "Y" ]] && return 0 || return 1
    fi

    local hint="y/N"
    [[ "$default" == "Y" ]] && hint="Y/n"

    read -rp "$(echo -e "${CYAN}?${NC}") ${prompt} [${hint}]: " -n 1 reply
    echo
    if [[ -z "$reply" ]]; then
        [[ "$default" == "Y" ]] && return 0 || return 1
    fi
    [[ "$reply" =~ ^[Yy]$ ]] && return 0 || return 1
}

# Wybor z listy opcji
ask_choice() {
    local prompt="$1"
    local default="$2"
    shift 2
    local options=("$@")

    if [[ "$NONINTERACTIVE" == "true" ]]; then
        echo "$default"
        return
    fi

    echo -e "${CYAN}?${NC} ${prompt}:"
    local i=1
    for opt in "${options[@]}"; do
        local marker=" "
        [[ "$opt" == "$default" ]] && marker="*"
        echo -e "  ${marker} ${i}) ${opt}"
        ((i++))
    done

    read -rp "$(echo -e "${CYAN}?${NC}") Wybor [${default}]: " choice

    if [[ -z "$choice" ]]; then
        echo "$default"
        return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
        echo "${options[$((choice-1))]}"
    else
        echo "$default"
    fi
}

# Cleanup handler
cleanup() {
    local exit_code=$?
    echo
    print_err "Instalacja przerwana! (kod: $exit_code)"
    echo "Log: ${LOG_FILE}"
    trap - SIGINT SIGTERM EXIT
    exit "$exit_code"
}

# --- WALIDACJA SRODOWISKA ---

# Sprawdz czy jestesmy na Jetsonie
check_jetson() {
    if [[ ! -f /proc/device-tree/model ]]; then
        print_warn "Nie wykryto platformy Jetson (/proc/device-tree/model brak)"
        if ! ask_yn "Kontynuowac mimo to?" "N"; then
            exit 1
        fi
        JETSON_MODEL="Unknown"
        return
    fi
    JETSON_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
}

# Auto-detekcja parametrow systemowych
detect_system() {
    # Architektura
    SYS_ARCH=$(uname -m)
    if [[ "$SYS_ARCH" != "aarch64" ]]; then
        print_warn "Architektura $SYS_ARCH - NJON jest zaprojektowany dla aarch64 (Jetson)"
        if ! ask_yn "Kontynuowac mimo to?" "N"; then
            exit 1
        fi
    fi

    # Liczba rdzeni CPU
    CPU_CORES=$(nproc 2>/dev/null || echo 4)

    # RAM
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))

    # Wolne miejsce na dysku
    DISK_FREE_GB=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}' || echo 0)

    # CUDA compute capability (jesli dostepne)
    CUDA_COMPUTE=""
    if command -v nvidia-smi &>/dev/null; then
        CUDA_COMPUTE=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '[:space:]')
    fi
    # Fallback dla Jetson Orin
    if [[ -z "$CUDA_COMPUTE" ]]; then
        if [[ "$JETSON_MODEL" == *"Orin"* ]]; then
            CUDA_COMPUTE="8.7"
        fi
    fi

    # Wersja Pythona
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "3.10")

    # Wersja Ubuntu
    UBUNTU_VERSION=$(. /etc/os-release 2>/dev/null && echo "$VERSION_ID" || echo "22.04")
    UBUNTU_CODENAME=$(. /etc/os-release 2>/dev/null && echo "$UBUNTU_CODENAME" || echo "jammy")

    # Sprawdz NVMe
    NVME_DEVICE=""
    if [[ -b /dev/nvme0n1 ]]; then
        NVME_DEVICE="/dev/nvme0n1"
    fi
}

# --- KONFIGURACJA PARAMETROW (WIZARD) ---

run_config_wizard() {
    echo
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}   KONFIGURACJA PARAMETROW INSTALACJI   ${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo
    echo -e "${DIM}Zebrane parametry zostana uzyte przez wszystkie komponenty.${NC}"
    echo -e "${DIM}Nacisnij Enter aby zaakceptowac wartosc domyslna [w nawiasach].${NC}"
    echo

    # --- 1. SWAP ---
    echo -e "${BOLD}--- SWAP ---${NC}"
    local swap_default="16"
    if (( TOTAL_RAM_GB <= 4 )); then
        swap_default="16"
    elif (( TOTAL_RAM_GB <= 8 )); then
        swap_default="16"
    else
        swap_default="8"
    fi
    ask_user "Rozmiar SWAP w GB (4/8/16/32)" "$swap_default" CFG_SWAP_SIZE
    # Walidacja
    if ! [[ "$CFG_SWAP_SIZE" =~ ^[0-9]+$ ]] || (( CFG_SWAP_SIZE < 1 || CFG_SWAP_SIZE > 64 )); then
        print_warn "Nieprawidlowy rozmiar SWAP, ustawiam $swap_default GB"
        CFG_SWAP_SIZE="$swap_default"
    fi
    echo

    # --- 2. CUDA / GPU ---
    echo -e "${BOLD}--- GPU / CUDA ---${NC}"
    local cuda_default="${CUDA_COMPUTE:-8.7}"
    ask_user "CUDA Compute Capability (auto: ${cuda_default})" "$cuda_default" CFG_CUDA_ARCH
    echo

    # --- 3. Kompilacja ---
    echo -e "${BOLD}--- KOMPILACJA ---${NC}"
    local jobs_default=$((CPU_CORES > 2 ? CPU_CORES - 2 : 1))
    ask_user "Liczba watkow kompilacji (CPU: ${CPU_CORES} rdzeni)" "$jobs_default" CFG_MAKE_JOBS
    if ! [[ "$CFG_MAKE_JOBS" =~ ^[0-9]+$ ]] || (( CFG_MAKE_JOBS < 1 )); then
        CFG_MAKE_JOBS="$jobs_default"
    fi
    echo

    # --- 4. OpenCV ---
    echo -e "${BOLD}--- OpenCV ---${NC}"
    ask_user "Wersja OpenCV" "4.10.0" CFG_OPENCV_VERSION
    echo

    # --- 5. Power Mode ---
    echo -e "${BOLD}--- TRYB ZASILANIA ---${NC}"
    echo "  Dostepne tryby dla Jetson Orin:"
    echo "    0 = MAXN (max wydajnosc, max pobor)"
    echo "    1 = 15W"
    echo "    2 = 7W (oszczedny)"
    ask_user "Tryb zasilania nvpmodel (0=MAXN/1=15W/2=7W)" "0" CFG_POWER_MODE
    if ! [[ "$CFG_POWER_MODE" =~ ^[0-2]$ ]]; then
        CFG_POWER_MODE="0"
    fi
    echo

    # --- 6. ROS2 ---
    echo -e "${BOLD}--- ROS2 ---${NC}"
    ask_user "ROS2 Domain ID (0-232)" "0" CFG_ROS_DOMAIN_ID
    if ! [[ "$CFG_ROS_DOMAIN_ID" =~ ^[0-9]+$ ]] || (( CFG_ROS_DOMAIN_ID > 232 )); then
        CFG_ROS_DOMAIN_ID="0"
    fi
    echo

    # --- 7. DeepStream ---
    echo -e "${BOLD}--- DeepStream ---${NC}"
    ask_user "Wersja DeepStream" "7.1" CFG_DEEPSTREAM_VERSION
    echo

    # --- 8. Ollama ---
    echo -e "${BOLD}--- Ollama (LLM) ---${NC}"
    ask_user "Model Ollama do pobrania (np. llama3:8b, gemma2:2b, puste=brak)" "" CFG_OLLAMA_MODEL
    echo

    # --- 9. OpenWebUI ---
    echo -e "${BOLD}--- OpenWebUI ---${NC}"
    ask_user "Port dla OpenWebUI" "3000" CFG_WEBUI_PORT
    if ! [[ "$CFG_WEBUI_PORT" =~ ^[0-9]+$ ]] || (( CFG_WEBUI_PORT < 1024 || CFG_WEBUI_PORT > 65535 )); then
        print_warn "Nieprawidlowy port, ustawiam 3000"
        CFG_WEBUI_PORT="3000"
    fi
    echo

    # --- 10. SSD ---
    echo -e "${BOLD}--- SSD/NVMe ---${NC}"
    if [[ -n "$NVME_DEVICE" ]]; then
        print_ok "Wykryto NVMe: $NVME_DEVICE"
        ask_user "Urzadzenie NVMe do migracji" "$NVME_DEVICE" CFG_SSD_DEVICE
    else
        print_warn "Nie wykryto urzadzenia NVMe"
        ask_user "Urzadzenie NVMe (puste=pomin migracje)" "" CFG_SSD_DEVICE
    fi
    echo

    # --- 11. Snapd ---
    echo -e "${BOLD}--- Snapd ---${NC}"
    ask_user "Rewizja snapd do zamrozenia" "24724" CFG_SNAPD_REVISION
    echo

    # --- ZAPIS KONFIGURACJI ---
    save_config
}

save_config() {
    cat > "${NJON_CONFIG}" << CFGEOF
# NJON Configuration - Generated $(date '+%Y-%m-%d %H:%M:%S')
# Mozesz edytowac ten plik i uruchomic: ./njon.sh -c njon.conf

# System
CFG_SWAP_SIZE=${CFG_SWAP_SIZE}
CFG_CUDA_ARCH=${CFG_CUDA_ARCH}
CFG_MAKE_JOBS=${CFG_MAKE_JOBS}
CFG_POWER_MODE=${CFG_POWER_MODE}
CFG_PYTHON_VERSION=${PYTHON_VERSION}

# OpenCV
CFG_OPENCV_VERSION=${CFG_OPENCV_VERSION}

# ROS2
CFG_ROS_DOMAIN_ID=${CFG_ROS_DOMAIN_ID}

# DeepStream
CFG_DEEPSTREAM_VERSION=${CFG_DEEPSTREAM_VERSION}

# Ollama
CFG_OLLAMA_MODEL=${CFG_OLLAMA_MODEL}

# OpenWebUI
CFG_WEBUI_PORT=${CFG_WEBUI_PORT}

# SSD
CFG_SSD_DEVICE=${CFG_SSD_DEVICE}

# Snapd
CFG_SNAPD_REVISION=${CFG_SNAPD_REVISION}
CFGEOF

    print_ok "Konfiguracja zapisana: ${NJON_CONFIG}"
    log "Config saved: SWAP=${CFG_SWAP_SIZE}G CUDA=${CFG_CUDA_ARCH} JOBS=${CFG_MAKE_JOBS} POWER=${CFG_POWER_MODE}"
}

load_config() {
    local conf_file="$1"
    if [[ ! -f "$conf_file" ]]; then
        print_err "Plik konfiguracyjny nie istnieje: $conf_file"
        exit 1
    fi
    # Laduj zmienne z pliku (tylko dozwolone klucze CFG_*)
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        if [[ "$key" =~ ^CFG_ ]]; then
            export "$key=$value"
        fi
    done < "$conf_file"
    PYTHON_VERSION="${CFG_PYTHON_VERSION:-3.10}"
    print_ok "Zaladowano konfiguracje z: $conf_file"
}

# --- DEFINICJE KOMPONENTOW ---

declare -A PART_NAMES=(
    [1]="SWAP (${CFG_SWAP_SIZE:-16}GB)"
    [2]="JetPack SDK + CUDA"
    [3]="Narzedzia developerskie"
    [4]="PyTorch, TensorFlow, ONNX"
    [5]="OpenCV z CUDA (dluuga kompilacja)"
    [6]="ROS2 Humble"
    [7]="DeepStream"
    [8]="Optymalizacja Jetsona"
    [9]="Test i weryfikacja"
    [10]="Ollama (LLM backend)"
    [11]="Docker + NVIDIA Container Toolkit"
    [12]="OpenWebUI (GUI dla LLM)"
    [13]="Poprawka Snapd"
    [14]="Przegladarki (chromium, firefox)"
    [15]="Migracja systemu na SSD/NVMe"
    [16]="Czyszczenie i konfiguracja koncowa"
)

declare -A DETECT_CMDS=(
    [1]='swapon --noheadings --show=NAME 2>/dev/null | grep -q "/swapfile"'
    [2]='command -v nvcc >/dev/null 2>&1 && nvcc --version >/dev/null 2>&1'
    [3]='dpkg -l build-essential 2>/dev/null | grep -q "^ii"'
    [4]='python3 -c "import torch" 2>/dev/null && python3 -c "import tensorflow" 2>/dev/null'
    [5]='python3 -c "import cv2; exit(0 if cv2.cuda.getCudaEnabledDeviceCount()>0 else 1)" 2>/dev/null'
    [6]='command -v ros2 >/dev/null 2>&1'
    [7]='test -d /opt/nvidia/deepstream/deepstream'
    [8]='nvpmodel -q 2>/dev/null | grep -qiE "MAXN|Mode[[:space:]]*:[[:space:]]*0"'
    [9]='test -f ~/test_installation.py'
    [10]='systemctl is-active --quiet ollama 2>/dev/null'
    [11]='command -v docker >/dev/null 2>&1 && docker info 2>/dev/null | grep -qi -e nvidia -e "Default Runtime: nvidia"'
    [12]='docker ps --format "{{.Names}}" 2>/dev/null | grep -q "openwebui"'
    [13]='command -v snap >/dev/null 2>&1'
    [14]='snap list 2>/dev/null | grep -qE "chromium|firefox"'
    [15]='findmnt -n -o SOURCE / 2>/dev/null | grep -q nvme'
    [16]='test -f ~/njon_installation_report.txt && grep -q "jetson-info" ~/.bashrc 2>/dev/null'
)

declare -A PART_DEPS=(
    [4]="2 3"
    [5]="2 3"
    [6]=""
    [7]="2"
    [8]="2"
    [9]="2"
    [11]=""
    [12]="10 11"
    [14]="13"
)

declare -A PART_DISK_REQ=(
    [1]=0
    [2]=5
    [3]=2
    [4]=8
    [5]=15
    [6]=5
    [7]=3
    [8]=0
    [9]=0
    [10]=2
    [11]=3
    [12]=5
    [13]=1
    [14]=2
    [15]=0
    [16]=0
)

# --- INICJALIZACJA ---

mkdir -p "${PARTS_DIR}"
touch "${STATE_FILE}" "${LOG_FILE}"

# Sprawdz skrypty
if [[ ! -d "${PARTS_DIR}" ]] || ! ls "${PARTS_DIR}"/part*.sh &>/dev/null; then
    print_err "Brak skryptow instalacyjnych w '${PARTS_DIR}'"
    echo "  Upewnij sie, ze pliki part*.sh sa w katalogu parts/"
    exit 1
fi

# Sprawdz root
if [[ $EUID -eq 0 ]]; then
    print_warn "Skrypt uruchomiony jako root (sudo)"
    echo "  Zalecane jest uruchomienie bez sudo: ./njon.sh"
    if ! ask_yn "Kontynuowac mimo to?" "N"; then
        exit 1
    fi
fi

# Detekcja systemu
check_jetson
detect_system

# Zaladuj konfiguracje
if [[ -n "$CONFIG_FILE" ]]; then
    load_config "$CONFIG_FILE"
elif [[ -f "${NJON_CONFIG}" ]]; then
    echo
    print_msg "Znaleziono zapisana konfiguracje: ${NJON_CONFIG}"
    if ask_yn "Uzyc zapisanej konfiguracji?" "Y"; then
        load_config "${NJON_CONFIG}"
    else
        run_config_wizard
    fi
else
    run_config_wizard
fi

# Aktualizuj nazwy po konfiguracji
PART_NAMES[1]="SWAP (${CFG_SWAP_SIZE:-16}GB)"
PART_NAMES[5]="OpenCV ${CFG_OPENCV_VERSION:-4.10.0} z CUDA"
PART_NAMES[7]="DeepStream ${CFG_DEEPSTREAM_VERSION:-7.1}"

# --- BANNER ---
clear
echo
echo -e "${BOLD}${BLUE}"
echo "  ================================================================"
echo "       NJON: Instalator AI/ML dla Jetson Orin  v${VERSION}"
echo "       JetPack 6.2.1 | CUDA 12.6 | Ubuntu ${UBUNTU_VERSION}"
echo "  ================================================================"
echo -e "${NC}"
echo -e "  Data:          $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  Host:          $(uname -n) | ${SYS_ARCH}"
echo -e "  Model:         ${JETSON_MODEL}"
echo -e "  RAM:           ${TOTAL_RAM_GB}GB"
echo -e "  Dysk wolny:    ${DISK_FREE_GB}GB"
echo -e "  CPU:           ${CPU_CORES} rdzeni"
echo -e "  CUDA Compute:  ${CFG_CUDA_ARCH:-brak}"
echo -e "  Python:        ${PYTHON_VERSION}"
echo

# Podsumowanie konfiguracji
echo -e "${BOLD}Konfiguracja:${NC}"
echo -e "  SWAP: ${CFG_SWAP_SIZE}GB | Watki: ${CFG_MAKE_JOBS} | Power: mode ${CFG_POWER_MODE} | OpenCV: ${CFG_OPENCV_VERSION}"
echo -e "  ROS2 Domain: ${CFG_ROS_DOMAIN_ID} | WebUI port: ${CFG_WEBUI_PORT} | Ollama model: ${CFG_OLLAMA_MODEL:-brak}"
[[ -n "$CFG_SSD_DEVICE" ]] && echo -e "  SSD: ${CFG_SSD_DEVICE}"
echo

# Pokaż ostatnia aktualizacje
LAST_UPDATE=$(get_state "LAST_UPDATE" "")
[[ -n "$LAST_UPDATE" ]] && echo -e "  ${DIM}Ostatnie sprawdzenie: $LAST_UPDATE${NC}"
echo

# Sprawdzenie miejsca
if (( DISK_FREE_GB < 20 )); then
    print_warn "Malo miejsca na dysku! Dostepne: ${DISK_FREE_GB}GB, zalecane: 20GB"
    if ! ask_yn "Kontynuowac mimo to?" "N"; then
        exit 1
    fi
fi

# Backup state file
if [[ -f "${STATE_FILE}" ]] && [[ -s "${STATE_FILE}" ]]; then
    cp "${STATE_FILE}" "${STATE_FILE}.bak" 2>/dev/null || true
fi

# --- AUTODETEKCJA ---
echo -e "${BOLD}Sprawdzam stan komponentow...${NC}"
echo "-------------------------------------------" | tee "${DETECT_LOG}"
log "Detection started"

for i in $(seq 1 16); do
    printf "  [%2d] %-42s" "$i" "${PART_NAMES[$i]}"

    if eval "${DETECT_CMDS[$i]}" 2>/dev/null; then
        state="success"
        echo -e " ${GREEN}OK${NC}" | tee -a "${DETECT_LOG}"
    else
        state="missing"
        echo -e " ${RED}BRAK${NC}" | tee -a "${DETECT_LOG}"
    fi

    update_state "PART_${i}" "$state"
done

update_state "LAST_UPDATE" "$(date '+%Y-%m-%d %H:%M:%S')"

echo
echo -e "${BOLD}Status komponentow:${NC}"
echo "-------------------------------------------"
echo

for i in $(seq 1 16); do
    state=$(get_state "PART_${i}" "missing")
    local_icon="${RED}BRAK${NC}"
    [[ "$state" == "success" ]] && local_icon="${GREEN}OK${NC}"
    printf "  [%2d] %-42s %b\n" "$i" "${PART_NAMES[$i]}" "$local_icon"
done
echo

# --- LISTA BRAKUJACYCH ---
INSTALL_LIST=""
MISSING_COUNT=0
for i in $(seq 1 16); do
    state=$(get_state "PART_${i}" "missing")
    if [[ "$state" != "success" ]]; then
        INSTALL_LIST="${INSTALL_LIST} ${i}"
        ((MISSING_COUNT++))
    fi
done

# --- GLOWNA LOGIKA ---
if [[ -z "${INSTALL_LIST// /}" ]]; then
    echo -e "${GREEN}${BOLD}Wszystkie skladniki wykryte jako zainstalowane!${NC}"
    echo
    echo "  1. Uruchom test srodowiska"
    echo "  2. Pokaz status"
    echo "  3. Wymus reinstalacje komponentu"
    echo "  q. Wyjdz"
    echo

    while true; do
        read -rp "Wybor: " ACTION
        case $ACTION in
            1)
                echo "Uruchamiam test..."
                python3 ~/test_installation.py || print_err "Test nie powiodl sie"
                break
                ;;
            2)
                for i in $(seq 1 16); do
                    state=$(get_state "PART_${i}" "missing")
                    local_icon="${RED}BRAK${NC}"
                    [[ "$state" == "success" ]] && local_icon="${GREEN}OK${NC}"
                    printf "  [%2d] %b %-42s\n" "$i" "$local_icon" "${PART_NAMES[$i]}"
                done
                echo
                read -rp "Enter aby kontynuowac..." _
                exec "$0"
                ;;
            3)
                echo "Ktory komponent przeinstalowac? (1-16)"
                read -rp "Numer: " REINSTALL_NUM
                if [[ "$REINSTALL_NUM" =~ ^[0-9]+$ ]] && (( REINSTALL_NUM >= 1 && REINSTALL_NUM <= 16 )); then
                    update_state "PART_${REINSTALL_NUM}" "missing"
                    print_ok "Oznaczono komponent [$REINSTALL_NUM] do reinstalacji"
                    sleep 1
                    exec "$0"
                else
                    print_err "Nieprawidlowy numer"
                    continue
                fi
                ;;
            q|Q) echo "Do zobaczenia!"; exit 0 ;;
            "") print_err "Nic nie wybrano!"; continue ;;
            *) print_err "Nieprawidlowy wybor"; continue ;;
        esac
    done
else
    echo "Brakujace komponenty ($MISSING_COUNT):${INSTALL_LIST}"
    echo
    echo "Opcje instalacji:"
    echo "  * Wpisz numery oddzielone spacja (np. 1 2 3)"
    echo "  * Wpisz 'all' aby zainstalowac wszystkie brakujace"
    echo "  * Wpisz 'q' aby wyjsc"
    echo

    while true; do
        read -rp "Wybor: " PART_SELECTION

        [[ -z "$PART_SELECTION" ]] && { print_err "Nic nie wybrano!"; continue; }
        [[ "$PART_SELECTION" == "q" || "$PART_SELECTION" == "Q" ]] && { echo "Do zobaczenia!"; exit 0; }

        if [[ "$PART_SELECTION" == "all" || "$PART_SELECTION" == "ALL" ]]; then
            PART_SELECTION=$INSTALL_LIST
            break
        fi

        VALID=true
        for num in $PART_SELECTION; do
            if ! [[ "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > 16 )); then
                print_err "Bledny numer: $num (dozwolone 1-16)"
                VALID=false
                break
            fi
        done

        [[ "$VALID" == "true" ]] && break
        echo "Sprobuj ponownie..."
    done

    # Ostrzezenia
    if [[ "$PART_SELECTION" == *5* ]]; then
        echo
        print_warn "OpenCV bedzie kompilowany! Czas: ~2-4h (${CFG_MAKE_JOBS} watkow)"
        print_warn "Wymagane miejsce: ~15GB"
        if ! ask_yn "Kontynuowac?" "Y"; then
            exec "$0"
        fi
    fi

    if [[ "$PART_SELECTION" == *15* ]]; then
        echo
        print_warn "Migracja na SSD wymaga podlaczonego dysku NVMe!"
        [[ -n "$CFG_SSD_DEVICE" ]] && echo "  Urzadzenie: ${CFG_SSD_DEVICE}"
        if ! ask_yn "Kontynuowac?" "Y"; then
            exec "$0"
        fi
    fi

    # --- INSTALACJA ---
    echo
    echo -e "${BOLD}Rozpoczynam instalacje wybranych komponentow...${NC}"
    echo "-------------------------------------------"

    trap cleanup SIGINT SIGTERM

    # Eksportuj konfiguracje dla skryptow part
    export CFG_SWAP_SIZE CFG_CUDA_ARCH CFG_MAKE_JOBS CFG_POWER_MODE
    export CFG_OPENCV_VERSION CFG_ROS_DOMAIN_ID CFG_DEEPSTREAM_VERSION
    export CFG_OLLAMA_MODEL CFG_WEBUI_PORT CFG_SSD_DEVICE CFG_SNAPD_REVISION
    export PYTHON_VERSION NJON_CONFIG

    START_TIME=$(date +%s)
    INSTALLED_COUNT=0
    SKIPPED_COUNT=0
    FAILED_COUNT=0

    for i in $PART_SELECTION; do
        SCRIPT=$(find "${PARTS_DIR}/" -maxdepth 1 -type f -name "part${i}_*.sh" 2>/dev/null | head -n1)
        if [[ -z "$SCRIPT" ]]; then
            print_warn "Skrypt part${i}_*.sh nie znaleziony!"
            continue
        fi

        chmod +x "$SCRIPT" 2>/dev/null || true

        state=$(get_state "PART_${i}" "missing")
        if [[ "$state" == "success" ]]; then
            echo -e "  [${i}] ${PART_NAMES[$i]} - juz zainstalowane, pomijam."
            ((SKIPPED_COUNT++))
            continue
        fi

        # Sprawdz wymagane miejsce
        local_disk_req=${PART_DISK_REQ[$i]:-0}
        if (( local_disk_req > 0 )); then
            current_free=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub(/G/,"",$4); print $4}' || echo 999)
            if (( current_free < local_disk_req )); then
                print_warn "[$i] Wymaga ${local_disk_req}GB, dostepne: ${current_free}GB"
                if ! ask_yn "Kontynuowac mimo to?" "N"; then
                    ((FAILED_COUNT++))
                    continue
                fi
            fi
        fi

        echo
        echo "============================================"
        echo "  [$i] Instaluje: ${PART_NAMES[$i]}"
        echo "============================================"
        log "Starting part $i: ${PART_NAMES[$i]}"

        PART_START=$(date +%s)

        # Uruchom skrypt i zachowaj prawidlowy exit code (PIPESTATUS)
        set +e
        bash "$SCRIPT" 2>&1 | tee -a "${LOG_FILE}"
        PART_EXIT=${PIPESTATUS[0]}
        set -e

        PART_END=$(date +%s)
        PART_TIME=$((PART_END - PART_START))

        if [[ $PART_EXIT -eq 0 ]]; then
            update_state "PART_${i}" "success"
            update_state "LAST_UPDATE" "$(date '+%Y-%m-%d %H:%M:%S')"
            print_ok "[$i] Zakonczone w $(format_time $PART_TIME)"
            log "Part $i completed in ${PART_TIME}s"
            ((INSTALLED_COUNT++))
        else
            update_state "PART_${i}" "failed"
            print_err "[$i] Blad instalacji! (kod: $PART_EXIT)"
            log "Part $i FAILED with exit code $PART_EXIT"
            ((FAILED_COUNT++))

            if ! ask_yn "Kontynuowac instalacje nastepnych komponentow?" "Y"; then
                break
            fi
        fi
    done

    END_TIME=$(date +%s)
    TOTAL_TIME=$((END_TIME - START_TIME))

    trap - SIGINT SIGTERM

    echo
    echo "==========================================="
    echo -e "${BOLD}PODSUMOWANIE INSTALACJI${NC}"
    echo "==========================================="
    echo -e "  Zainstalowane:  ${GREEN}${INSTALLED_COUNT}${NC}"
    echo -e "  Pominiete:      ${YELLOW}${SKIPPED_COUNT}${NC}"
    echo -e "  Bledy:          ${RED}${FAILED_COUNT}${NC}"
    echo -e "  Czas:           $(format_time $TOTAL_TIME)"
    echo -e "  Log:            ${LOG_FILE}"
    echo

    if [[ $INSTALLED_COUNT -gt 0 ]]; then
        echo "Nastepne kroki:"
        echo "  1. source ~/.bashrc (lub zrestartuj terminal)"
        echo "  2. python3 ~/test_installation.py (test srodowiska)"
        echo "  3. sudo reboot (zalecane po instalacji)"
    fi

    echo
    echo "Co chcesz teraz zrobic?"
    echo "  1. Uruchom test srodowiska"
    echo "  2. Pokaz ostatnie linie logu"
    echo "  3. Uruchom njon.sh ponownie"
    echo "  q. Zakoncz"
    echo

    while true; do
        read -rp "Wybor: " POST_ACTION
        case $POST_ACTION in
            1) python3 ~/test_installation.py || print_err "Test nie powiodl sie"; break ;;
            2) echo "--- Ostatnie 30 linii logu ---"; tail -n 30 "${LOG_FILE}"; echo; read -rp "Enter..."; exec "$0" ;;
            3) exec "$0" ;;
            q|Q) echo "Dziekuje za uzycie NJON!"; exit 0 ;;
            "") print_err "Nic nie wybrano!"; continue ;;
            *) print_err "Nieprawidlowy wybor"; continue ;;
        esac
    done
fi

echo
echo "Dziekuje za uzycie NJON!"
