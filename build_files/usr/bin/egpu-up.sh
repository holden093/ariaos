#!/usr/bin/env bash
set -e

# Controllo stringente sui privilegi di root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Errore: Questo script deve essere eseguito come root o con sudo."
    exit 1
fi

echo "==> Rilevamento hardware eGPU..."
# Cerca la scheda NVIDIA sul bus PCIe
if ! lpcie=$(lspci | grep -i nvidia); then
    echo "❌ Errore: Nessuna eGPU NVIDIA rilevata sul bus PCIe."
    echo "    Verifica che il cavo Thunderbolt sia collegato e autorizzato."
    exit 1
fi
echo "    Trovato hardware: $lpcie"

echo "==> Caricamento moduli NVIDIA per Compute..."
# Carica i moduli core gestendo le dipendenze in automatico
# Usiamo --ignore-install per bypassare il blocco di sicurezza nel file modprobe.d
if modprobe --ignore-install nvidia && modprobe --ignore-install nvidia_uvm; then
    echo "✅ Moduli caricati con successo."
else
    echo "❌ Errore: Impossibile caricare i moduli NVIDIA."
    exit 1
fi

# Inizializza i file di device in /dev (fondamentale per Podman/Docker)
if command -v nvidia-modprobe &> /dev/null; then
    echo "==> Inizializzazione device nodes..."
    nvidia-modprobe -c0 -u
    # Isola la GPU dalle app desktop assegnandola al gruppo ai-compute e rimuovendo le ACL utente
    echo "==> Restrizione permessi per Compute Mode..."
    setfacl -b /dev/nvidia* 2>/dev/null || true
    chgrp ai-compute /dev/nvidia* 2>/dev/null || true
    chmod 0660 /dev/nvidia*
fi

echo "==> Verifica stato CUDA..."
if command -v nvidia-smi &> /dev/null; then
    echo "------------------------------------------------"
    nvidia-smi -L
    echo "------------------------------------------------"
    echo "✅ eGPU NVIDIA configurata e pronta per l'inferenza."
else
    echo "❌ Errore: moduli caricati ma nvidia-smi non risponde."
    exit 1
fi
