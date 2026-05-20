# NixitOS Best Practices

## Fedora Silverblue & bootc
- **Minimalism**: Only include packages in the base image that are essential for the system to boot and provide core functionality. Use Flatpaks or Distroboxes for user applications.
- **GitOps Flow**: Every change should be reflected in the `Containerfile`. Avoid manual `rpm-ostree install` on the running system except for testing.
- **Clean Layers**: Always run `rpm-ostree cleanup -m` after installs to keep image size down.

## eGPU Management (NVIDIA)
- **Early Loading**: Ensure `nvidia` and `nvidia_uvm` are not loaded   if eGPU is detected. The eGPU usage should be OPTIONAL and "on-demand"
- **Power Management**: Use `powertop` to monitor if the eGPU is consuming power when idle.
- **Clean Unload**: Always ensure processes using the GPU are killed before unloading modules to avoid kernel panics or hung states.

## Intel Arc (Compute)
- **Compute Runtime**: Ensure `intel-compute-runtime` and `libva-intel-media-driver` are correctly configured for hardware acceleration in apps like OBS or FFmpeg.

## Build Optimization
- **Mount Cache**: Use `--mount=type=cache,dst=/var/cache` in `Containerfile` to speed up builds by caching RPM metadata and packages.
- **Bootc Lint**: Always run `bootc container lint` at the end of the build.
