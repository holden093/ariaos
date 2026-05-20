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
    chmod +x /usr/bin/egpu-up.sh /usr/bin/egpu-down.sh && \
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
    ModemManager \
    cups \
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
    # --- Virtualizzazione ---
    libvirt \
    virt-manager \
    qemu-kvm \
    # --- Sviluppo & Varie ---
    nodejs-npm \
    git \
    gh \
    # --- Pacchetti utente ---
    remmina \
    steam-devices \
    geary \
    vlc \
    rbw \
    btop \
    powertop \
    nvtop \
    obs-studio \
    obs-studio-plugin-x264 \
    podman-compose \
    distrobox && \
    # --- Pulizia ---
    rpm-ostree cleanup -m && \
    # --- Abilitazione servizi ---
    systemctl enable podman.socket

# ==========================================
# 3. BRANDING & IDENTITÀ
# ==========================================

RUN sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="NixitOS (BlueBuild Edition)"/' /etc/os-release && \
    sed -i 's/^NAME=.*/NAME="NixitOS"/' /etc/os-release && \
    sed -i 's/^ID=fedora/ID=nixitos/' /etc/os-release && \
    sed -i 's/^ID_LIKE=.*/ID_LIKE="fedora"/' /etc/os-release && \
    sed -i 's|^HOME_URL=.*|HOME_URL="https://git.nixit.it/holden093/NixitOS"|' /etc/os-release

# ==========================================
# 4. PLYMOUTH & INITRAMFS
# ==========================================

RUN cp /usr/share/plymouth/themes/spinner/throbber-*.png /usr/share/plymouth/themes/nixitos/ && \
    plymouth-set-default-theme nixitos

# ==========================================
# 5. VERIFICA E LINTING
# ==========================================

RUN bootc container lint
