#!/usr/bin/env bash
echo "Avvio moduli NVIDIA per Compute..."

# Carica i moduli core per abilitare CUDA e VRAM
sudo modprobe nvidia
sudo modprobe nvidia_uvm

# Verifica che la scheda sia stata riconosciuta
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi -L
    echo "eGPU NVIDIA pronta per l'inferenza."
else
    echo "Errore: nvidia-smi non trovato o scheda non rilevata."
fi
