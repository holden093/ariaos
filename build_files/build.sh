#!/usr/bin/env bash
set -ouex pipefail

echo "=== Inizio Build Sistema Custom ==="

# 1. Copia i file custom nel sistema operativo
# Usiamo rsync per mantenere i permessi e gestire bene i link simbolici
rsync -a /ctx/rootfs/ /

# 2. Imposta i permessi di esecuzione per gli script
chmod +x /usr/bin/egpu-up.sh
chmod +x /usr/bin/egpu-down.sh

# 3. Installa i pacchetti aggiuntivi
# rtirq è utile per dare priorità massima ai thread audio USB (Scarlett)
rpm-ostree install rtirq

# 4. Pulizia cache per ridurre le dimensioni finali
rpm-ostree clean -m

echo "=== Build Completata ==="
