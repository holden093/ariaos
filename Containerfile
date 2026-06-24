# syntax=docker/dockerfile:1
FROM scratch AS ctx
COPY build_files /

# ==========================================
# STAGE: Rebuild FreeRDP with FFmpeg/x264 + VAAPI
# ==========================================
# Isolated from the main image to avoid libavcodec-free / ffmpeg-libs
# conflicts between Fedora and RPM Fusion packages.

FROM fedora:44 AS freerdp-builder
RUN dnf install -y 'dnf-command(builddep)' rpm-build && \
    dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm && \
    dnf install -y ffmpeg-devel && \
    dnf builddep --define '_with_ffmpeg 1' -y freerdp && \
    dnf download --source freerdp && \
    rpmbuild --rebuild \
        --define '_with_ffmpeg 1' \
        --define 'dist .ariaos' \
        freerdp-*.src.rpm && \
    echo "AriaOS: FreeRDP RPMs built with FFmpeg/x264 + VAAPI."

# L'immagine base pulita con i driver NVIDIA
FROM ghcr.io/blue-build/base-images/fedora-silverblue-nvidia:44

# ==========================================
# 1. COPIA FILE CUSTOM E PERMESSI
# ==========================================

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    rsync -a /ctx/ / && \
    chmod +x /usr/bin/egpu-up.sh /usr/bin/egpu-down.sh /usr/bin/backup /usr/bin/restore /usr/bin/ariaos-daw-launcher /usr/bin/aria && \
    chmod 0440 /etc/sudoers.d/egpu /etc/sudoers.d/tuned

# ==========================================
# 1b. ABILITAZIONE RPM FUSION, CODEC & OTTIMIZZAZIONE
# ==========================================

# Consolidiamo l'installazione dei repository e la rimozione di pacchetti ingombranti/inutili
RUN rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm && \
    rpm-ostree override remove \
    glibc-all-langpacks \
    gnome-software \
    ibus-typing-booster \
    ibus-anthy \
    ibus-anthy-python \
    ibus-hangul \
    ibus-libpinyin \
    ibus-m17n \
    ibus-unikey \
    google-noto-sans-cjk-fonts \
    cldr-emoji-annotation \
    cldr-emoji-annotation-dtd && \
    rpm-ostree cleanup -m

# ==========================================
# 2. PACCHETTI RPM E SERVIZI (Consolidati)
# ==========================================

RUN --mount=type=cache,dst=/var/cache \
    # Fix for Mono (CKAN dependency) missing cert.pem during rpm-ostree post-install
    ln -s /etc/pki/tls/certs/ca-bundle.crt /etc/pki/tls/cert.pem && \
    rpm-ostree install \
    # --- Codec & Multimedia ---
    libva-intel-media-driver \
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
    loupe \
    evince \
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
    python3-pip \
    ripgrep \
    distrobox \
    ckan \
    borgbackup \
    btrfsmaintenance \
    # --- Audio & Low-Latency ---
    realtime-setup \
    tuned \
    tuned-profiles-realtime && \
    # --- Pulizia ---
    rpm-ostree cleanup -m && \
    # --- Abilitazione servizi ---
    systemctl enable podman.socket tuned.service btrfs-scrub.timer btrfs-balance.timer && \
    systemctl mask ModemManager.service && \
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
    echo "AriaOS: NVIDIA is now on-demand only."

# ==========================================
# 2b. OVERRIDE FREERDP WITH FFMPEG/x264 + VAAPI BUILD
# ==========================================

# Copy all RPMs built in the isolated freerdp-builder stage and
# replace the stock packages.  freerdp-libs and libwinpr are version-
# locked (must match), and both are present in the base image.

COPY --from=freerdp-builder /root/rpmbuild/RPMS/x86_64/ /tmp/freerdp-rpms/
RUN rpm-ostree override replace \
        /tmp/freerdp-rpms/freerdp-libs-[0-9]*.rpm \
        /tmp/freerdp-rpms/libwinpr-[0-9]*.rpm && \
    rm -rf /tmp/freerdp-rpms && \
    rpm-ostree cleanup -m && \
    echo "AriaOS: FreeRDP replaced with FFmpeg/x264 + VAAPI build."

# ==========================================
# 2c. CHATBOT LOCALE (aria) — venv
# ==========================================

RUN python3 -m venv --system-site-packages /usr/share/aria/venv && \
    /usr/share/aria/venv/bin/pip install ddgs && \
    rm -rf /usr/share/aria/venv/.cache

# ==========================================
# 3. BRANDING & IDENTITÀ
# ==========================================

RUN sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="AriaOS (BlueBuild Edition)"/' /etc/os-release && \
    sed -i 's/^NAME=.*/NAME="AriaOS"/' /etc/os-release && \
    sed -i 's/^ID=fedora/ID=ariaos/' /etc/os-release && \
    sed -i 's/^ID_LIKE=.*/ID_LIKE="fedora"/' /etc/os-release && \
    sed -i 's|^HOME_URL=.*|HOME_URL="https://github.com/holden093/airaos"|' /etc/os-release

# ==========================================
# 4. PLYMOUTH & INITRAMFS
# ==========================================

RUN cp -n /usr/share/plymouth/themes/spinner/*.png /usr/share/plymouth/themes/ariaos/ && \
    plymouth-set-default-theme ariaos && \
    # Creiamo /var/roothome per evitare che dracut fallisca a causa di /root come symlink rotto nel container
    mkdir -p /var/roothome && \
    # Rigeneriamo l'initramfs ALLA FINE per applicare le esclusioni NVIDIA e TPM
    dracut -f --regenerate-all

# ==========================================
# 5. VERIFICA E LINTING
# ==========================================

RUN bootc container lint
