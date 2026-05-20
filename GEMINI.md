# NixitOS - Agent Instructions

This file contains foundational mandates and context for any AI agent working on the NixitOS codebase.

## 1. Architectural Paradigm
- **System Type:** Fedora Silverblue derivative using `bootc` and `blue-build`.
- **GitOps Flow:** The system is immutable. ALL system-level changes (packages, services, configuration files) MUST be made by editing the `Containerfile` or placing files in the `build_files/` directory. Do not instruct the user to run `dnf` or `rpm-ostree install` on their live system unless it's for temporary testing.

## 2. Hardware Constraints & Asymmetric GPU Setup
This specific configuration is bound to the user's local hardware:
- **Primary GPU & Compute:** Intel Arc (Lunar Lake). Packages like `intel-compute-runtime` and `intel-level-zero` are critical for everyday acceleration and base LLM inference via SYCL/Vulkan.
- **On-Demand eGPU:** NVIDIA GPU via Thunderbolt. 
  - **CRITICAL RULE:** NVIDIA kernel modules (`nvidia`, `nvidia_uvm`, `nouveau`) MUST remain blacklisted in `/etc/modprobe.d/blacklist-nvidia.conf`. 
  - The eGPU is strictly activated manually via `egpu-up.sh` when heavy compute is needed. Do not introduce packages or services that force the NVIDIA driver to load at boot or integrate it with the Wayland/GNOME display server.

## 3. Optimization Goals (AI/LLM Focus)
- **Minimalism:** Keep the base image as small as possible. 
  - `glibc-all-langpacks` is explicitly removed to save space, but `glibc-langpack-it` and `langpacks-it` must be kept to support the user's primary locale (Italian) alongside English.
  - Prefer Flatpaks or Distroboxes for GUI applications not explicitly requested in the base image.
- **RAM Efficiency:** The system has 32GB of physical RAM, primarily intended for loading large weights in `llama.cpp`. 
  - zRAM is explicitly configured to 16GB with the `zstd` algorithm to compress OS/background tasks and prevent OOM without stealing physical RAM from the model. Do not alter this balance without explicit user confirmation.

## 4. Documentation & Maintenance
- **Active Skills:** Use the `nixitos-optimizer` skill to periodically check system efficiency.
- **Always-Sync Docs:** Every structural change MUST be reflected in both `GEMINI.md` (for the agent) and `README.md` (for the user).
- **Update Frequency:** Documentation is not static; update it whenever a package is added/removed or a service is tuned.
