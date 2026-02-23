#!/bin/bash
set -euo pipefail

WEBUI_PORT="${CFG_WEBUI_PORT:-3000}"

echo "[OpenWebUI] Instalacja OpenWebUI (port: ${WEBUI_PORT})..."

# Sprawdz czy Docker jest dostepny
if ! command -v docker &>/dev/null; then
    echo "[OpenWebUI] BLAD: Docker nie jest zainstalowany!"
    echo "[OpenWebUI] Zainstaluj najpierw komponent 11 (Docker)"
    exit 1
fi

# Sprawdz czy Docker dziala
if ! sudo docker info &>/dev/null; then
    echo "[OpenWebUI] BLAD: Docker nie dziala. Uruchamiam..."
    sudo systemctl start docker
    sleep 3
fi

# Sprawdz czy kontener juz dziala
if sudo docker ps --format "{{.Names}}" 2>/dev/null | grep -q "openwebui"; then
    echo "[OpenWebUI] Kontener openwebui juz dziala"
    sudo docker ps --filter name=openwebui --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 0
fi

# Sprawdz czy port jest wolny
if ss -tlnp 2>/dev/null | grep -q ":${WEBUI_PORT} " || netstat -tlnp 2>/dev/null | grep -q ":${WEBUI_PORT} "; then
    echo "[OpenWebUI] UWAGA: Port ${WEBUI_PORT} jest juz zajety!"
    echo "[OpenWebUI] Zmien port w konfiguracji lub zwolnij port"
fi

# Usun stary kontener jesli istnieje (ale nie dziala)
sudo docker rm -f openwebui 2>/dev/null || true

# Pobierz obraz
echo "[OpenWebUI] Pobieranie obrazu Docker..."
sudo docker pull --platform linux/arm64 ghcr.io/open-webui/open-webui:ollama || {
    echo "[OpenWebUI] Obraz z tagiem :ollama nie dostepny dla ARM64"
    echo "[OpenWebUI] Probuje standardowy obraz..."
    sudo docker pull --platform linux/arm64 ghcr.io/open-webui/open-webui:main || {
        echo "[OpenWebUI] BLAD: Nie udalo sie pobrac obrazu"
        exit 1
    }
    WEBUI_IMAGE="ghcr.io/open-webui/open-webui:main"
}
WEBUI_IMAGE="${WEBUI_IMAGE:-ghcr.io/open-webui/open-webui:ollama}"

# Uruchom kontener
echo "[OpenWebUI] Uruchamianie kontenera..."
sudo docker run -d \
    -p "${WEBUI_PORT}:8080" \
    --gpus=all \
    -v ollama:/root/.ollama \
    -v open-webui:/app/backend/data \
    --name openwebui \
    --restart always \
    "$WEBUI_IMAGE"

# Czekaj na uruchomienie
echo "[OpenWebUI] Czekam na uruchomienie..."
for i in $(seq 1 30); do
    if sudo docker ps --filter name=openwebui --filter status=running -q 2>/dev/null | grep -q .; then
        echo "[OpenWebUI] OK - kontener dziala!"
        break
    fi
    sleep 2
done

# Weryfikacja
if sudo docker ps --filter name=openwebui --filter status=running -q 2>/dev/null | grep -q .; then
    echo "[OpenWebUI] OK - Dostep: http://localhost:${WEBUI_PORT}"
    sudo docker ps --filter name=openwebui --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "[OpenWebUI] UWAGA: Kontener moze nie dzialac prawidlowo"
    echo "[OpenWebUI] Sprawdz logi: sudo docker logs openwebui"
fi
