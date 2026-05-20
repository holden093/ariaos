---
name: nixitos-optimizer
description: Specialized for optimizing NixitOS (a Fedora-based bootc image). It compares the codebase (Containerfile, build_files) with the current running environment to identify performance bottlenecks, redundant packages, and better configuration patterns. Use it to improve system efficiency and maintainability.
---

# NixitOS Optimizer

This skill helps you refine the NixitOS codebase by comparing it with the active operating system and applying efficiency best practices for Fedora Silverblue/bootc images.

## Core Workflows

### 1. Codebase vs. Environment Analysis
- Compare the list of packages in `Containerfile` with the output of `rpm-ostree status` and `rpm -qa`.
- Identify "ghost" packages that are installed but never used or have more efficient alternatives.
- Check active services (`systemctl list-units --type=service --state=running`) and cross-reference with the codebase to see if they are necessary or can be optimized.

### 2. Layer & Build Optimization
- Group `rpm-ostree install` commands to reduce image layers.
- Use multi-stage builds if necessary for temporary build tools.
- Ensure `rpm-ostree cleanup -m` is used after every major install step.

### 3. Performance Tuning
- Suggest `sysctl` tweaks based on hardware (e.g., eGPU usage, SSD optimization).
- Optimize eGPU scripts (`egpu-up.sh`, `egpu-down.sh`) for faster loading and better error handling.
- Review `blacklist-nvidia.conf` and other `modprobe.d` configs to ensure proper driver management.

### 4. Hardware-Specific Refinements
- Use `lshw`, `lspci`, and `lsusb` to detect hardware and suggest missing drivers or firmware in the `Containerfile`.
- Optimize for Intel Arc compute tasks if `intel-compute-runtime` is present.

## Best Practices
- Refer to `references/best-practices.md` for detailed guidance on `blue-build` and `bootc`.
- Use `scripts/check_efficiency.sh` to gather a performance baseline before making changes.
