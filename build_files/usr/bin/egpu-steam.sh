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
    # Forza udev a rivalutare i permessi ora che nvidia_drm è caricato (disabilita il blocco compute)
    udevadm trigger --action=change /dev/nvidia*
    # Attende che udev finisca di processare i nuovi device e i trigger
    udevadm settle
    
    # Assicuriamoci che i permessi siano corretti per l'utente corrente
    chmod 0666 /dev/nvidia* 2>/dev/null || true
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
