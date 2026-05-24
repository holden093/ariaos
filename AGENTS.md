# NixitOS - Agent Instructions

This file contains foundational mandates and context for any AI agent working on the NixitOS codebase.

## 1. Architectural Paradigm
- **System Type:** Fedora Silverblue derivative using `bootc` and `blue-build`.
- **GitOps Flow:** The system is immutable. ALL system-level changes (packages, services, configuration files) MUST be made by editing the `Containerfile` or placing files in the `build_files/` directory. Do not instruct the user to run `dnf` or `rpm-ostree install` on their live system unless it's for temporary testing.

## 2. Hardware Constraints & Asymmetric GPU Setup
This specific configuration is bound to the user's local hardware:
- **Primary GPU & Compute:** Intel Arc (Lunar Lake). Packages like `intel-compute-runtime` and `intel-level-zero` are critical for everyday acceleration and base LLM inference via SYCL/Vulkan.
- **On-Demand eGPU:** NVIDIA GPU via Thunderbolt. 
  - **CRITICAL RULE:** NVIDIA kernel modules (`nvidia`, `nvidia_uvm`, `nouveau`, `nvidia_modeset`, `nvidia_drm`) MUST remain blacklisted via `install <module> /bin/false` in `/etc/modprobe.d/blacklist-nvidia.conf`. Do not use `alias <module> off` as it breaks explicit `--ignore-install` loading.
  - **Usage:** Activated via `egpu-up.sh`. Loads the full stack (`nvidia`, `nvidia_uvm`, `nvidia_modeset`, `nvidia_drm`) and sets wide-open permissions (`0666`) to allow both compute and display server (Wayland/GNOME) to hook the GPU.
  - **Disconnection (Cold-Unplug Required):** Because `egpu-up.sh` loads DRM modules and allows the display server to capture the device, the eGPU CANNOT be hot-unplugged safely. The user MUST log out or reboot to release the GPU before running `egpu-down.sh` or disconnecting.

## 3. Optimization Goals (AI/LLM Focus)
- **Minimalism:** Keep the base image as small as possible. 
  - `glibc-all-langpacks` is explicitly removed to save space, but `glibc-langpack-it` and `langpacks-it` must be kept to support the user's primary locale (Italian) alongside English.
  - Prefer Flatpaks or Distroboxes for GUI applications not explicitly requested in the base image.
  - **CRITICAL RULE:** Flatpaks MUST NEVER be used for "critical" system applications (e.g. Backup tools, core system utilities). Such applications MUST always be installed as native RPMs in the base image.
    - **EXCEPTION:** *Pika Backup* is explicitly authorized to be installed via Flatpak (`org.gnome.World.PikaBackup`) despite being a critical backup tool, as approved by the system administrator to prioritize its native GNOME GTK aesthetic and functionality.
- **RAM Efficiency:** The system has 32GB of physical RAM, primarily intended for loading large weights in `llama.cpp`. 
  - zRAM is explicitly configured to 16GB with the `zstd` algorithm to compress OS/background tasks and prevent OOM without stealing physical RAM from the model. Do not alter this balance without explicit user confirmation.
- **CPU & Storage Efficiency:** The NMI watchdog is disabled (`nowatchdog`) to allow deeper C-states. The Btrfs root filesystem is explicitly mounted with `compress=zstd:1` via `bootc` kargs (`build_files/usr/lib/bootc/kargs.d/battery.toml`) to reduce write amplification and save battery.
  - **BTRFS Health (btrfsmaintenance):** To proactively prevent bit-rot and ensure metadata integrity over time, the `btrfsmaintenance` package is integrated in the base image. Systemd timers (`btrfs-scrub.timer` and `btrfs-balance.timer`) are explicitly enabled to perform regular asynchronous checks in the background.

## 4. Disk Encryption & TPM 2.0 Security
- **LUKS2 and TPM2 Bindings:** NixitOS supports modern LUKS2 disk encryption bound to TPM 2.0 via `systemd-cryptenroll`.
- **Declarative Zero-Config Paradigm:** To uphold the atomic, immutable GitOps philosophy of `bootc`, manual modification of `/etc/crypttab` on the host is strongly discouraged. The system relies on the **Discoverable Partitions Specification (DPS)**. Under GPT, `systemd-gpt-auto-generator` automatically discovers the root LUKS2 volume at boot, reads the TPM2 token from the LUKS2 JSON metadata header, and unlocks it without host state modifications.
- **Dracut Configuration:** Because `bootc` builds are performed inside containers where no TPM is present, `crypt` and `tpm2-tss` dracut modules are explicitly forced in [tpm2.conf](file:///var/home/kevin/GIT/NixitOS/build_files/etc/dracut.conf.d/tpm2.conf) to guarantee that they are packaged into the initramfs.
- **TPM PCR Strategy:**
  - Standard binding should use **PCR 7** (Secure Boot state) and optionally **PCR 0** (Firmware).
  - **AVOID PCR 8 and 9** on `bootc` systems, as these measure kernel command lines and initramfs content. Since `bootc update` pulls new images with updated kernels and initramfs, binding to PCR 8/9 would trigger a recovery passphrase prompt on every single system upgrade.


## 5. Empirical Validation & Testing Mandate (Strict Protocol)
- **Test Before Act:** NEVER propose a modification without first performing empirical tests to verify the actual state of the system. Do not make naive assumptions about standard configurations.
- **Verification:** Always use tools like `lsmod`, `systemctl`, `lsblk`, or `--dry-run` flags (e.g., for `dracut` or package managers) to cross-reference the real system state before acting.
- **Post-Fix Validation:** Every change must be rigorously validated post-implementation to guarantee syntactical correctness and ensure no regressions were introduced.
- **CRITICAL TIMEOUT RULE:** If a command or build (like `podman build`) goes into timeout waiting for a permission prompt, it means the user is away from the computer. Do NOT assume the command succeeded, and do NOT bypass the verification step. You must STOP, report the timeout, and wait for the user. NEVER take anything for granted.

## 6. Documentation & Maintenance
- **Active Skills:** Use the `nixitos-optimizer` skill to periodically check system efficiency, and the `nixitos-posture-check` skill to verify alignment with this repo's desired state.
- **Always-Sync Docs:** Every structural change MUST be reflected in both `AGENTS.md` (for the agent) and `README.md` (for the user).
- **Update Frequency:** Documentation is not static; update it whenever a package is added/removed or a service is tuned.

## 7. Project License
- **License Type:** GNU General Public License v3.0 (GPL-3.0).
- **Enforcement:** Ensure any new files or major contributions respect the copyleft nature of the GPL v3.0. The `LICENSE` file in the root directory is the source of truth.

## 8. Backup & Restore Capabilities
NixitOS implements a two-tier backup architecture:
- **Daily Incremental Backups (Time Machine-like):** The primary daily backup solution is **Pika Backup** (BorgBackup under the hood). This provides browsable, incremental backups over the network (e.g., to a TrueNAS SMB share). Since Pika Backup is heavily GNOME-integrated, an exception exists to install it via Flatpak (`org.gnome.World.PikaBackup`).
- **Bare-Metal Disaster Recovery (TUI Scripts):** NixitOS provides native interactive TUI scripts (`nixitos-home-backup` and `nixitos-home-restore`) located in `build_files/usr/bin/` to safely export and import the entire `/var/home` Btrfs subvolume to USB drives.
- **Methodology (Bare-Metal):** They rely on Btrfs `send` and `receive` streams compressed via `zstd`, alongside `dialog` and `pv` for the UI. Future agents modifying the storage layout or subvolume naming scheme must ensure these scripts are updated to reflect those changes.
- **Dynamic Subvolumes (GitOps Storage):** Heavy data like LLM weights and Steam games are excluded from the `/var/home` backup. This is achieved declaratively via `systemd-tmpfiles` (`build_files/usr/lib/tmpfiles.d/nixitos-subvols.conf`), which automatically creates native Btrfs subvolumes in `/var` (`/var/llms`, `/var/games`) and exposes them via symlinks in the user's home directory. Since Btrfs snapshots are not recursive, `nixitos-home-backup` only backs up the symlinks (and Pika Backup can be configured to exclude them).

## 9. Low-Latency Audio Optimizations (Dynamic Tuning)
- **Kernel Tuning:** To maximize battery life and allow deep C-states on Intel Lunar Lake, NixitOS explicitly avoids boot-time realtime kernel arguments like `threadirqs` and `preempt=full`. The system relies on the standard Fedora kernel scheduling, which provides sufficiently low latencies out-of-the-box via PipeWire. Do NOT replace the kernel with third-party RT kernels (like CachyOS) as it breaks pre-compiled NVIDIA drivers.
- **Dynamic DAW Tuning:** When launching a DAW (e.g., Reaper), users should use the `nixitos-daw-launcher` wrapper script. This script dynamically switches the system to the `latency-performance` tuned profile via `sudo` (allowed passwordless via `/etc/sudoers.d/tuned`) for the duration of the session, and restores `balanced-battery` upon exit.
- **Priority Management:** `realtime-setup` is installed. Users MUST be added to the `realtime` and `audio` groups to take advantage of PAM `limits.d` capabilities.
