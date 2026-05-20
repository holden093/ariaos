# syntax=docker/dockerfile:1
FROM scratch AS ctx
COPY build_files /

# L'immagine base pulita con i driver NVIDIA già allineati al kernel stock di Fedora 43
FROM ghcr.io/blue-build/base-images/fedora-silverblue-nvidia:43

# Esegue lo script di build sfruttando le cache avanzate
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
# Verifica di integrità del bootable container
RUN bootc container lint
