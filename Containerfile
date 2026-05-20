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
# 1b. ABILITAZIONE RPM FUSION & CODEC
# ==========================================

RUN rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm && \
    rpm-ostree cleanup -m

RUN --mount=type=cache,dst=/var/cache \
    rpm-ostree install \
    # Manteniamo solo il driver unificato moderno
    libva-intel-media-driver \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-libav \
    lame && \
    rpm-ostree cleanup -m

# ==========================================
# 2. PACCHETTI RPM E SERVIZI
# ==========================================

RUN --mount=type=cache,dst=/var/cache \
    rpm-ostree install \
    # --- Runtime per Intel Arc (Calcolo) ---
    intel-compute-runtime \
    # --- Gestione Hardware & eGPU ---
    bolt \
    pciutils \
    lshw \
    glx-utils \
    # --- Networking & Sysadmin tools ---
    wireguard-tools \
    nmap \
    iperf3 \
    mtr \
    tcpdump \
    bind-utils \
    tmux \
    jq \
    libvirt \
    virt-manager \
    qemu-kvm \
    ffmpeg \
    x264-libs \
    obs-studio \
    obs-studio-plugin-x264 \
    # --- Pacchetti utente & Varie ---
    git \
    remmina \
    steam-devices \
    geary \
    vlc \
    rbw \
    btop \
    powertop \
    nvtop \
    podman-compose \
    distrobox && \
    # --- Pulizia ---
    rpm-ostree cleanup -m && \
    # --- Abilito servizio di podman all'avvio ---
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
