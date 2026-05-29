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

## 10. Local LLM Architecture (NixitOS GGUF Engine)
- **Engine Management:** The local `llama.cpp` container is managed directly via `podman compose` using the compose definition at `/usr/share/nixit-gguf-engine/compose.yaml`. Use `podman compose -f /usr/share/nixit-gguf-engine/compose.yaml up -d` to start the engine.
- **Engine Definition:** The GGUF engine compose, router config, and Containerfiles are maintained in this repo under `build_files/usr/share/nixit-gguf-engine/` and installed to `/usr/share/nixit-gguf-engine/`. Runtime state only belongs under `/var` or user state directories; the engine must not depend on ad-hoc directories in the user's home.
- **Model Storage:** All downloaded models and configs must reside in `/var/llms` (symlinked to `~/LLMs/ggufs`). This guarantees they survive OS image updates and avoid bloating standard `/var/home` backups.

## 11. Local Terminal Chatbot (aria)

### Purpose
`aria` is a terminal-based AI chatbot integrated into the NixitOS base image. It connects via SSE streaming to the local llama.cpp inference container (`nixit-gguf-engine` on `http://127.0.0.1:8080/v1`) and provides a conversational REPL with OpenAI-compatible function calling.

### Location
`build_files/usr/bin/aria` is the single canonical command and the only chatbot entrypoint maintained in this repository. Do not add compatibility aliases or duplicate wrapper commands unless the user explicitly requests them.

### Runtime Dependencies
- **System venv:** `/usr/share/aria/venv` (created at build time in the Containerfile with `python3 -m venv --system-site-packages`, inheriting system `requests` and `psutil`). The only pip dependency installed in this venv is `ddgs` (DuckDuckGo search).
- **Containerfile addition:** `python3-pip` RPM, plus a dedicated RUN step that creates the venv and runs `pip install ddgs`.
- **Python imports used:** `requests`, `json`, `datetime`, `os`, `sys`, `signal`, `textwrap`, `shutil`, `subprocess`, `random`, `re`, `pathlib`, `psutil` (lazy-imported in `system_info()`), `ddgs` (DuckDuckGo, try/except fallback to `duckduckgo_search`).

### Environment Variables (no hardcoded values)
All user/host-specific values are resolved dynamically or via environment variables:
| Variable | Default | Purpose |
|---|---|---|
| `LLAMA_API` | `http://127.0.0.1:8080/v1` | llama.cpp OpenAI-compatible endpoint |
| `ARIA_MODEL` | auto-detected from `/v1/models` (loaded `32k` profiles are preferred, then other loaded models), fallback `qwen3-4b-instruct-2507-ud-q6xl-32k`. | Model to use |
| `ARIA_COMPOSE` | `/usr/share/nixit-gguf-engine/compose.yaml` (with repo fallback during development). | Compose file for auto-starting the engine |
| `NIXIT_WORK_DIR` | `os.cwd()` | Write-allowed directory for `write_file()` |

**Hardcoding rule:** NEVER add user-specific data (hostname, CPU model, RAM size, hardcoded paths). Always use `os.uname().nodename`, `psutil.cpu_count()`, `psutil.virtual_memory().total`, `os.getenv(...)` with sensible defaults, or `Path.home()`.

### Architecture

#### Streaming Engine
`call_llm_stream(messages, tools, max_tokens=2048)` sends `stream: true` to the API and yields typed event dicts:
- `{"type": "reasoning", "text": "..."}` — Gemma4 thinking tokens (shown in gray, natural terminal wrapping)
- `{"type": "content", "text": "..."}` — response tokens (streamed to stdout)
- `{"type": "done", "reason": "stop"|"tool_calls"|"length", "usage": {...}, "timings": {...}, "tool_calls": [...]}` — final event with stats

SSE parsing handles `data:` lines, `[DONE]` marker, and JSON decode errors gracefully. Tool calls are accumulated across streaming chunks (indexed by `tc["index"]`).

#### Tool Calling Loop
Each user message enters a `while tool_rounds < 5 and not done_final` loop:
1. Stream the API response
2. If `done` with `reason: "tool_calls"` → execute tool(s), append results to messages, continue loop
3. If `done` with `reason: "stop"` → display content, show stats, set `done_final = True`
4. Error handling: ConnectionError, HTTP errors, timeout

#### Tools (5 total)
All defined in the `TOOLS` list (OpenAI function-calling schema) and `TOOL_IMPL` dict. Model sees them in every request.

1. **`web_search(query)`** — DuckDuckGo via `ddgs` library. Max 5 results, snippet truncated at 200 chars.
2. **`system_info(category)`** — Uses `psutil` for CPU %, RAM, swap, disk usage, processes (top 10 by RAM). GPU detection via `lsmod | grep nvidia_uvm`.
3. **`read_file(path)`** — Resolves `~`, validates existence/is_file. Limits: 1 MB size, 10k chars read. UTF-8 with error replacement.
4. **`write_file(path, content)`** — Ensures `resolve()`d path starts with `NIXIT_WORK_DIR.resolve()`. Creates parent dirs. Blocks path traversal (`../`, `~/`, `/tmp/`).
5. **`run(command)`** — Whitelisted read-only shell commands. Blocks pipes, redirects, sudo, destructive operations. 15s timeout, output capped at 5k chars.

#### Reasoning Display
When `show_reasoning` is True (toggled via `/think`), thinking tokens print in gray with natural terminal wrapping. A `🧠` prefix marks the thinking. When content tokens arrive, the thinking display naturally flows into the response with a visual gap. No `\r` tricks — the terminal handles wrapping.

#### Interaction Features
- `/think` — toggle thinking visibility
- `/model` — list available models from API
- `/new` — clear conversation history
- Multiline input: `"""..."""` syntax for pasting blocks
- Auto-start: if engine unreachable, runs `podman compose up -d` with configurable compose path
- History persistence: JSON file at `~/.local/share/aria-history.json` (last 100 messages)
- Exit messages: randomized from `EXIT_MSGS` list

#### Model Selection and Local Memory Budget
`detect_model()` must prefer loaded `32k` profiles over `128k` profiles. The laptop GGUF engine is intended to stay within an approximate 10 GiB shared GPU-memory budget; long-context work belongs on `api.ai.nixit.it` or another remote server. Do not expose or auto-select 128k laptop profiles unless the user explicitly accepts the memory and latency cost.

#### System Prompt
Dynamically built by `get_system_prompt()` — injects `os.uname().nodename`, kernel version, CPU count (`psutil.cpu_count()`), RAM (`psutil.virtual_memory().total`). Personality: "Aria", Italian sysadmin, friendly/competent. Rules: proactive (try common paths first), never conservative (always search fresh), offer to save structured output.

### Testing Mandate
Any modification must pass:
1. Syntax check (`py_compile`)
2. Non-interactive smoke test against running API (verify tool calling, web search, system_info)
3. No hardcoded user/host-specific values (grep for hostname, CPU model, RAM size, fixed paths)
4. The Containerfile must build the ctx stage without errors
