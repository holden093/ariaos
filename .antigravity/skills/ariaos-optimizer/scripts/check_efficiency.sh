#!/usr/bin/env bash

echo "=== AriaOS Efficiency Report ==="
echo "Date: $(date)"
echo "Kernel: $(uname -r)"

echo -e "\n--- 1. Base System Info ---"
if [ -f /etc/os-release ]; then
    grep -E '^(NAME|PRETTY_NAME|ID|VERSION_ID)=' /etc/os-release
fi

echo -e "\n--- 2. Package Stats ---"
echo "Total RPMs installed: $(rpm -qa | wc -l)"
echo "Top 10 largest packages (approx):"
rpm -qa --queryformat '%{SIZE} %{NAME}\n' | sort -rn | head -10 | awk '{print $2, $1/1024/1024 "MB"}'

echo -e "\n--- 3. Active Services (Systemd) ---"
systemctl list-units --type=service --state=running --no-pager | head -n 20

echo -e "\n--- 4. Hardware Detection (eGPU & Intel Arc) ---"
echo "NVIDIA Devices:"
lspci | grep -i nvidia || echo "None detected."
echo "Intel Graphics/Compute Devices:"
lspci | grep -i vga | grep -i intel || echo "None detected."

echo -e "\n--- 5. Boot Time Performance ---"
if command -v systemd-analyze &> /dev/null; then
    systemd-analyze
    echo "Top 5 critical path services:"
    systemd-analyze critical-chain | head -n 10
fi

echo -e "\n--- 6. Power Management Status ---"
if [ -d /sys/class/power_supply ]; then
    ls /sys/class/power_supply
fi

echo -e "\n=== End of Report ==="
