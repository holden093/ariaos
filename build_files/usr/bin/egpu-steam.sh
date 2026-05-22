#!/usr/bin/env bash
set -e

# Controllo stringente sui privilegi di root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Errore: Questo script deve essere eseguito come root o con sudo."
    exit 1
fi

echo "==> Rilevamento hardware eGPU..."
if ! lpcie=$(lspci | grep -i nvidia); then
    echo "❌ Errore: Nessuna eGPU NVIDIA rilevata sul bus PCIe."
    echo "    Verifica che il cavo Thunderbolt sia collegato e autorizzato."
    exit 1
fi
echo "    Trovato hardware: $lpcie"

echo "==> Caricamento moduli NVIDIA per Gaming (Rendering Grafico)..."
# Carichiamo tutti i moduli necessari per Wayland/X11 e DRM
if modprobe --ignore-install nvidia && \
   modprobe --ignore-install nvidia_modeset && \
   modprobe --ignore-install nvidia_uvm && \
   modprobe --ignore-install nvidia_drm; then
    echo "✅ Moduli di rendering grafico caricati con successo."
else
    echo "❌ Errore: Impossibile caricare i moduli NVIDIA."
    exit 1
fi

# Inizializza i file di device in /dev
if command -v nvidia-modprobe &> /dev/null; then
    echo "==> Inizializzazione device nodes..."
    nvidia-modprobe -c0 -u
fi

echo "==> Verifica stato GPU..."
if command -v nvidia-smi &> /dev/null; then
    echo "------------------------------------------------"
    nvidia-smi -L
    echo "------------------------------------------------"
    echo "✅ eGPU NVIDIA configurata per il gaming! Il launcher avvierà Steam a breve."
else
    echo "❌ Errore: moduli caricati ma nvidia-smi non risponde."
    exit 1
fi
