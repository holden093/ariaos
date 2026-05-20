#!/usr/bin/env bash
echo "Scaricamento moduli NVIDIA..."

# Scarica i moduli dalla memoria
sudo rmmod nvidia_uvm
sudo rmmod nvidia

echo "Moduli scaricati. Ora puoi scollegare fisicamente la eGPU in sicurezza."
