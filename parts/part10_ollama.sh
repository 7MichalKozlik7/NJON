#!/bin/bash
set -e
echo "[Ollama] Instalacja..."
curl -fsSL https://ollama.com/install.sh | sudo OLLAMA_YES=1 sh
sudo systemctl enable ollama
sudo systemctl start ollama
ollama list || echo "[INFO] Brak modeli – możesz pobrać np. 'ollama pull llama3:8b'"
echo "[Ollama] OK"
