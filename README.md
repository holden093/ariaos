sudo podman build -f Containerfile -t localhost/nixitos:latest .

sudo podman run --rm -it --privileged \
  -v $(pwd)/output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso \
  --rootfs ext4 \
  localhost/nixitos:latest
