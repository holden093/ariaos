# syntax=docker/dockerfile:1
FROM scratch AS ctx
COPY build_files /

# L'immagine base pulita con i driver NVIDIA
FROM ghcr.io/blue-build/base-images/fedora-silverblue-nvidia:44

# ==========================================
# 1. COPIA FILE CUSTOM E PERMESSI
# ==========================================

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    rsync -a /ctx/ / && \
    chmod +x /usr/bin/egpu-up.sh /usr/bin/egpu-down.sh /usr/bin/egpu-steam.sh /usr/bin/nixitos-home-backup /usr/bin/nixitos-home-restore && \
    chmod 0440 /etc/sudoers.d/egpu

# ==========================================
# 1b. ABILITAZIONE RPM FUSION, CODEC & OTTIMIZZAZIONE
# ==========================================

# Consolidiamo l'installazione dei repository e la rimozione di pacchetti ingombranti/inutili
RUN rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm && \
    rpm-ostree override remove \
    glibc-all-langpacks \
    gnome-software && \
    rpm-ostree cleanup -m

# ==========================================
# 2. PACCHETTI RPM E SERVIZI (Consolidati)
# ==========================================

RUN --mount=type=cache,dst=/var/cache \
    rpm-ostree install \
    # --- Codec & Multimedia ---
    libva-intel-media-driver \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-libav \
    lame \
    ffmpeg \
    x264-libs \
    # --- Runtime per Intel Arc (Calcolo & LLM) ---
    intel-compute-runtime \
    intel-level-zero \
    # --- Gestione Hardware & eGPU ---
    bolt \
    pciutils \
    lshw \
    lm_sensors \
    glx-utils \
    vulkan-loader \
    vulkan-tools \
    clinfo \
    # --- Networking & Sysadmin tools ---
    wireguard-tools \
    nmap \
    iperf3 \
    mtr \
    tcpdump \
    bind-utils \
    tmux \
    jq \
    dialog \
    pv \
    # --- Virtualizzazione ---
    libvirt \
    virt-manager \
    qemu-kvm \
    # --- Sviluppo & Varie ---
    glibc-langpack-it \
    langpacks-it \
    nodejs-npm \
    git \
    gh \
    # --- UI & Personalizzazione ---
    yaru-theme \
    gnome-tweaks \
    gnome-shell-extension-user-theme \
    # --- Pacchetti utente ---
    remmina \
    steam-devices \
    geary \
    gedit \
    vlc \
    rbw \
    btop \
    powertop \
    nvtop \
    obs-studio \
    obs-studio-plugin-x264 \
    podman-compose \
    ripgrep \
    distrobox && \
    # --- Pulizia ---
    rpm-ostree cleanup -m && \
    # --- Abilitazione servizi ---
    systemctl enable podman.socket && \
    # --- Enforce NVIDIA Blacklist & On-Demand policy ---
    # Rimuoviamo le configurazioni che forzano il caricamento dei driver o del modesetting
    rm -f /usr/lib/dracut/dracut.conf.d/99-nvidia.conf && \
    rm -f /usr/lib/modprobe.d/nvidia-modeset.conf && \
    rm -f /usr/lib/modprobe.d/nvidia.conf && \
    # Disabilitiamo i servizi che forzano il caricamento dei moduli NVIDIA all'avvio
    systemctl mask nvidia-hibernate.service \
                   nvidia-resume.service \
                   nvidia-suspend.service \
                   nvidia-suspend-then-hibernate.service \
                   nvidia-powerd.service \
                   nvidia-persistenced.service && \
    # Rimuoviamo kargs di default di bluebuild che forzano il caricamento dei driver
    rm -f /usr/lib/bootc/kargs.d/bluebuild-kargs.toml && \
    echo "NixitOS: NVIDIA is now on-demand only."

# ==========================================
# 3. BRANDING & IDENTITÀ
# ==========================================

RUN sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="NixitOS (BlueBuild Edition)"/' /etc/os-release && \
    sed -i 's/^NAME=.*/NAME="NixitOS"/' /etc/os-release && \
    sed -i 's/^ID=fedora/ID=nixitos/' /etc/os-release && \
    sed -i 's/^ID_LIKE=.*/ID_LIKE="fedora"/' /etc/os-release && \
    sed -i 's|^HOME_URL=.*|HOME_URL="https://git.nixit.it/holden093/NixitOS"|' /etc/os-release && \
    # Sostituiamo i loghi di GDM/Fedora ridimensionandoli (una via di mezzo per GDM, es. 192x192)
    ffmpeg -y -v quiet -i /usr/share/plymouth/themes/nixitos/logo.png -vf "scale=192:192:force_original_aspect_ratio=decrease" /usr/share/pixmaps/system-logo-white.png && \
    cp /usr/share/pixmaps/system-logo-white.png /usr/share/pixmaps/fedora-gdm-logo.png || true

# ==========================================
# 4. PLYMOUTH & INITRAMFS
# ==========================================

RUN cp -n /usr/share/plymouth/themes/spinner/*.png /usr/share/plymouth/themes/nixitos/ && \
    # Rimpiccioliamo i loghi di plymouth per evitare che siano giganti a schermo in fase di boot
    ffmpeg -y -v quiet -i /usr/share/plymouth/themes/nixitos/logo.png -vf "scale=256:256:force_original_aspect_ratio=decrease" /usr/share/plymouth/themes/nixitos/bgrt-fallback.png && \
    ffmpeg -y -v quiet -i /usr/share/plymouth/themes/nixitos/logo.png -vf "scale=128:128:force_original_aspect_ratio=decrease" /usr/share/plymouth/themes/nixitos/watermark.png && \
    plymouth-set-default-theme nixitos && \
    # Creiamo /var/roothome per evitare che dracut fallisca a causa di /root come symlink rotto nel container
    mkdir -p /var/roothome && \
    # Rigeneriamo l'initramfs ALLA FINE per applicare le esclusioni NVIDIA, TPM e includere il nuovo logo Plymouth
    dracut -f --regenerate-all

# ==========================================
# 5. VERIFICA E LINTING
# ==========================================

RUN bootc container lint
