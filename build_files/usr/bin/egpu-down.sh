#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
    echo "❌ Errore: Questo script deve essere eseguito como root o con sudo."
    exit 1
fi

echo "==> Controllo processi attivi sulla eGPU..."
# Forza la chiusura di container o script Python che tengono bloccata la GPU
if command -v nvidia-smi &> /dev/null; then
    PIDS=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits 2>/dev/null || true)
    if [ -n "$PIDS" ] && [ "$PIDS" != "No devices found" ]; then
        echo "⚠️ Rilevati processi attivi sulla eGPU (PIDs: $PIDS)."
        echo "    Invio segnale di terminazione (SIGTERM)..."
        echo "$PIDS" | xargs -r kill -15
        sleep 2
    fi
fi

echo "==> Rimozione moduli NVIDIA dal kernel..."
# Usiamo modprobe -r per scaricare i moduli in modo pulito seguendo l'albero delle dipendenze
modprobe -r nvidia_uvm 2>/dev/null || echo "    Modulo UVM non presente o già rimosso."
modprobe -r nvidia_drm 2>/dev/null
modprobe -r nvidia_modeset 2>/dev/null
modprobe -r nvidia 2>/dev/null

# Verifica finale sullo stato del kernel
if lsmod | grep -q nvidia; then
    echo "❌ Errore: Alcuni moduli NVIDIA sono ancora in uso dal sistema."
    echo "    Impossibile scollegare la eGPU in sicurezza in questo momento."
    exit 1
else
    echo "✅ Moduli rimossi con successo."
    echo "    Ora puoi scollegare fisicamente il cavo Thunderbolt."
fi
