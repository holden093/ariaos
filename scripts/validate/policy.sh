#!/usr/bin/env bash
set -Eeuo pipefail

readonly image_sources=(Containerfile build_files scripts/build versions)

if rg -n '(^|/)(var/home/kevin|home/kevin)|\bkevin\b' "${image_sources[@]}"; then
  echo "User-specific path or account found in the image definition." >&2
  exit 1
fi

readonly removed_model_pattern='aria-gguf-engine|/var/llms|\bddgs\b'
removed_model_matches=$(
  rg -n -i "$removed_model_pattern" "${image_sources[@]}" |
    rg -v 'rm -rf /usr/share/aria /usr/share/aria-gguf-engine' || true
)
if [[ -n $removed_model_matches ]]; then
  printf '%s\n' "$removed_model_matches"
  echo "Retired local-model component found in the host image definition." >&2
  exit 1
fi

# Nessun motore di inferenza deve essere installato o costruito nell'immagine:
# l'host fornisce la toolchain Vulkan; i server vivono in /var/home o in container scelti dall'utente.
if rg -n -i 'install.*\bllama\b|\bgit clone.*llama|copy.*\bllama-server' \
    scripts/build Containerfile; then
  echo "LLM engine installation found in the build definition." >&2
  exit 1
fi
if rg -n '(usr/(s)?bin/|usr/libexec/)(llama|llama-server|llama-cli)' build_files; then
  echo "LLM engine binary found in build_files." >&2
  exit 1
fi

if rg -n -i 'nvidia|nouveau|cuda|ariaos-egpu|nvidia-container-toolkit|\bcdi\b' \
    "${image_sources[@]}"; then
  echo "NVIDIA/CUDA component found in the Intel-only image definition." >&2
  exit 1
fi

if rg -n 'llama-vm|vfio-pci|/var/vms|ariaos-vfio' build_files scripts/build versions tests; then
  echo "Retired VM inference path still referenced." >&2
  exit 1
fi
if ! rg -q 'rm -f /usr/bin/llama-vm' Containerfile; then
  echo "Containerfile must remove the retired llama-vm binary." >&2
  exit 1
fi

if [[ -e build_files/usr/lib/udev/rules.d/69-ariaos-vfio.rules ]]; then
  echo "Retired VFIO udev rule still present." >&2
  exit 1
fi

if ! grep -Fq 'virtqemud.socket' scripts/build/configure-services.sh; then
  echo "Missing virtqemud.socket enablement in configure-services.sh." >&2
  exit 1
fi

if grep -Eq '^v /var/vms ' build_files/usr/lib/tmpfiles.d/ariaos-subvols.conf; then
  echo "/var/vms subvolume declaration must be removed." >&2
  exit 1
fi

echo "Image contract policy passed."
