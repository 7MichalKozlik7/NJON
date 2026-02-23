#!/bin/bash
set -euo pipefail

SSD_DEVICE="${CFG_SSD_DEVICE:-/dev/nvme0n1}"

echo "[SSD] Migracja systemu na SSD/NVMe"

# Sprawdz czy juz na NVMe
ROOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null || echo "unknown")
if echo "$ROOT_DEV" | grep -q nvme; then
    echo "[SSD] System juz dziala z NVMe ($ROOT_DEV)"
    echo "[SSD] Migracja nie jest potrzebna."
    exit 0
fi

# Sprawdz czy urzadzenie istnieje
if [[ -z "$SSD_DEVICE" ]]; then
    echo "[SSD] BLAD: Nie podano urzadzenia SSD"
    exit 1
fi

if [[ ! -b "$SSD_DEVICE" ]]; then
    echo "[SSD] BLAD: Urzadzenie ${SSD_DEVICE} nie istnieje!"
    echo "[SSD] Dostepne urzadzenia NVMe:"
    ls /dev/nvme* 2>/dev/null || echo "  (brak)"
    echo "[SSD] Dostepne dyski:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null || true
    exit 1
fi

# Pokaz informacje o urzadzeniu
echo "[SSD] Urzadzenie docelowe: ${SSD_DEVICE}"
echo "[SSD] Informacje o dysku:"
sudo fdisk -l "$SSD_DEVICE" 2>/dev/null | head -5 || true
echo

# Potwierdzenie
echo "[SSD] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "[SSD] UWAGA: Ta operacja SKASUJE dane na ${SSD_DEVICE}!"
echo "[SSD] Upewnij sie ze to wlasciwe urzadzenie!"
echo "[SSD] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo

read -rp "[SSD] Wpisz 'TAK' aby kontynuowac migracje: " confirm
if [[ "$confirm" != "TAK" ]]; then
    echo "[SSD] Operacja anulowana"
    exit 0
fi

# Klonowanie narzedzi migracyjnych
MIGRATE_DIR="${HOME}/migrate-jetson-to-ssd"
echo "[SSD] Przygotowanie narzedzi migracyjnych..."

if [[ -d "$MIGRATE_DIR" ]]; then
    echo "[SSD] Katalog migracyjny juz istnieje"
    cd "$MIGRATE_DIR"
    git pull 2>/dev/null || true
else
    git clone https://github.com/jetsonhacks/migrate-jetson-to-ssd.git "$MIGRATE_DIR"
    cd "$MIGRATE_DIR"
fi

# Weryfikacja skryptow
for script in make_partitions.sh copy_partitions.sh configure_ssd_boot.sh; do
    if [[ ! -f "$script" ]]; then
        echo "[SSD] BLAD: Brak skryptu $script"
        exit 1
    fi
done

# Wykonanie migracji
echo "[SSD] Tworzenie partycji na ${SSD_DEVICE}..."
sudo bash make_partitions.sh

echo "[SSD] Kopiowanie systemu plikow..."
sudo bash copy_partitions.sh

echo "[SSD] Konfiguracja bootloadera..."
sudo bash configure_ssd_boot.sh

echo
echo "[SSD] ============================================"
echo "[SSD] Migracja zakonczona!"
echo "[SSD] ============================================"
echo
echo "[SSD] Nastepne kroki:"
echo "  1. Zrestartuj system: sudo reboot"
echo "  2. Po restarcie sprawdz: findmnt /"
echo "  3. Opcjonalnie rozszerz partycje:"
echo "     sudo parted ${SSD_DEVICE}"
echo "       (parted) print"
echo "       (parted) resizepart 1 100%"
echo "       (parted) quit"
echo "     sudo resize2fs ${SSD_DEVICE}p1"
echo
echo "[SSD] WAZNE: Zrestartuj Jetsona aby dokonczyc migracje!"
