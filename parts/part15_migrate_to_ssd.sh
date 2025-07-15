#!/bin/bash
set -e

echo "[SSD MIGRACJA] Klonowanie systemu rootfs na SSD/NVMe"
echo "UWAGA: system zostanie skopiowany na /dev/nvme0n1 – upewnij się, że to właściwe urządzenie!"

read -p "▶️ Kontynuować migrację na /dev/nvme0n1 (rootfs)? [Y/n]: " confirm
if [[ $confirm != "Y" && $confirm != "y" ]]; then
  echo "❌ Operacja anulowana"
  exit 0
fi

echo "[SSD MIGRACJA] Klonuję repozytorium narzędzi migracyjnych od JetsonHacks..."
cd ~
git clone https://github.com/jetsonhacks/migrate-jetson-to-ssd.git || true
cd migrate-jetson-to-ssd

echo "[SSD MIGRACJA] Tworzenie partycji..."
sudo bash make_partitions.sh

echo "[SSD MIGRACJA] Kopiowanie partycji systemowej..."
sudo bash copy_partitions.sh

echo "[SSD MIGRACJA] Konfiguracja bootloadera do SSD..."
sudo bash configure_ssd_boot.sh

echo "[SSD MIGRACJA] Sprawdź/użyj narzędzia 'parted' do rozszerzenia rootfs na SSD..."

echo "▶️ Teraz możesz rozszerzyć partycję rootfs do pełnego rozmiaru:"
echo "  1. sudo fdisk -l /dev/nvme0n1"
echo "  2. sudo parted /dev/nvme0n1"
echo "     (parted) print"
echo "     (parted) resizepart 1 100%"
echo "     (parted) quit"
echo
echo "▶️ Po tym rozszerz system plików:"
echo "  sudo resize2fs /dev/nvme0n1p1"

echo
echo "[✅ SSD MIGRACJA] Migracja zakończona. Zrestartuj Jetsona!"
