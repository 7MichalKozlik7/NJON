#!/bin/bash
set -euo pipefail

OLLAMA_MODEL="${CFG_OLLAMA_MODEL:-}"

echo "[Ollama] Instalacja Ollama (LLM backend)..."

# Sprawdz czy juz zainstalowane
if command -v ollama &>/dev/null; then
    echo "[Ollama] Ollama juz zainstalowane:"
    ollama --version 2>/dev/null || true
    echo "[Ollama] Sprawdzam serwis..."
else
    echo "[Ollama] Pobieranie i instalacja..."
    curl -fsSL https://ollama.com/install.sh | sudo OLLAMA_YES=1 sh || {
        echo "[Ollama] BLAD: Instalacja nie powiodla sie"
        exit 1
    }
fi

# Wlacz i uruchom serwis
echo "[Ollama] Konfiguracja serwisu..."
sudo systemctl enable ollama 2>/dev/null || true
sudo systemctl start ollama 2>/dev/null || true

# Poczekaj na uruchomienie
echo "[Ollama] Czekam na uruchomienie serwisu..."
for i in $(seq 1 15); do
    if systemctl is-active --quiet ollama 2>/dev/null; then
        echo "[Ollama] Serwis aktywny"
        break
    fi
    sleep 2
done

if ! systemctl is-active --quiet ollama 2>/dev/null; then
    echo "[Ollama] UWAGA: Serwis nie uruchomil sie automatycznie"
    echo "[Ollama] Sprobuj: sudo systemctl restart ollama"
fi

# Pobranie modelu jesli skonfigurowany
if [[ -n "$OLLAMA_MODEL" ]]; then
    echo "[Ollama] Pobieranie modelu: ${OLLAMA_MODEL}..."
    echo "[Ollama] To moze potrwac w zaleznosci od rozmiaru modelu..."
    ollama pull "$OLLAMA_MODEL" || {
        echo "[Ollama] UWAGA: Nie udalo sie pobrac modelu ${OLLAMA_MODEL}"
        echo "[Ollama] Mozesz pobrac pozniej: ollama pull ${OLLAMA_MODEL}"
    }
fi

# Pokaz dostepne modele
echo "[Ollama] Zainstalowane modele:"
ollama list 2>/dev/null || echo "  (brak modeli)"

echo "[Ollama] OK - Ollama API: http://localhost:11434"
