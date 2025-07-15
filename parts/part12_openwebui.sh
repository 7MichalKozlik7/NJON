#!/bin/bash
set -e
echo "[OpenWebUI] Instalacja..."
sudo docker pull ghcr.io/open-webui/open-webui:ollama
sudo docker rm -f openwebui || true
sudo docker run -d -p 3000:8080 --gpus=all \
  -v ollama:/root/.ollama \
  -v open-webui:/app/backend/data \
  --name openwebui --restart always \
  ghcr.io/open-webui/open-webui:ollama
echo "[OpenWebUI] Dostęp przez http://localhost:3000"
