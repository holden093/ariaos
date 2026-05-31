# NixitOS

## Project

Immutable Fedora Silverblue derivative using bootc and blue-build, purpose-built for asymmetric dual-GPU AI/LLM workloads on Intel Arc (primary) + NVIDIA eGPU (on-demand). Tech stack: Fedora 44, bootc, blue-build, Containerfile, Podman Compose, bash (system scripts), Python (aria chatbot).

## Structure

Non-standard: the Containerfile at repo root defines a bootc-compatible OS image. build_files/ mirrors a Linux filesystem layout (etc/, usr/bin/, usr/share/) and is rsynced into the container during build.

## Commands

- Build OS image locally: `podman build -f Containerfile -t nixitos .`
- CI builds: pushed to ghcr.io on push to main, or daily at 10:05 UTC via scheduled workflow
- Lint (run inside container build as final step): `bootc container lint`
- Activate NVIDIA eGPU (on-demand only): `sudo egpu-up.sh`
- Deactivate NVIDIA eGPU: requires logout/reboot first, then `sudo egpu-down.sh`
- Chat with local AI: `aria`
- Export home backup: `sudo backup`
- Restore home backup on fresh install: `sudo restore`

## Conventions

- NVIDIA modules are never loaded at boot. The file build_files/etc/modprobe.d/blacklist-nvidia.conf uses `install <module> /bin/false` (not `alias <module> off`, which breaks `--ignore-install` loading). Activation requires explicit `modprobe --ignore-install` via egpu-up.sh.
- Btrfs subvolumes for heavy data (llms/, games/) are created via systemd-tmpfiles, symlinked under /var/home, excluded from home snapshots so backups stay lean.
- zRAM is configured at 16GB zstd to keep 32GB physical RAM available for LLM inference models.
- LLM context is capped at 32k for local inference; 128k profiles are explicitly excluded from config.ini -- they are only available via the remote inference API at api.ai.nixit.it.
- Flatpaks must never be used for critical system apps (backup tools, core utilities). Exception: Pika Backup is authorized as a Flatpak for GNOME integration.
- Scripts in usr/bin use `set -euo pipefail` (bash) and are installed with `chmod +x` in the Containerfile.

## Key Files

- `Containerfile` -- OS image definition: packages, services, branding, NVIDIA blacklist, initramfs regeneration, bootc lint.
- `build_files/usr/bin/aria` -- Local AI chatbot (824 lines Python): system-prompt-based assistant with tool calling, web search, system info, file read/write. Auto-starts the GGUF engine if not running.
- `build_files/usr/bin/egpu-up.sh` -- NVIDIA eGPU activation script: loads blacklisted kernel modules via modprobe --ignore-install, initializes device nodes with 0666 permissions.
- `build_files/usr/share/nixit-gguf-engine/compose.yaml` -- Podman Compose definition for llama.cpp inference container with SYCL device passthrough and healthcheck.
- `$HOME/LLMs/GGUF/config.ini` — LLM router preset with model profiles, context window sizes, and hardware constraints. The compose bind-mounts it into the container at `/config/config.ini`. User-owned, survives OS updates.
- `build_files/usr/share/nixit-gguf-engine/compose.yaml` — Podman Compose definition for the llama.cpp inference container (uses upstream `ghcr.io/ggml-org/llama.cpp:server-intel` directly, all config in the compose).
- `AGENTS.md` -- Technical architecture reference: hardware constraints, optimization rules, validation mandates, and the source of truth for AI agents working on the project.
- `.github/workflows/build-image.yml` -- CI/CD pipeline: buildah build, GHCR push, daily rebuild schedule, PR preview builds.
