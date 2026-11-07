#!/usr/bin/env bash
set -Eeuo pipefail

readonly versions_file=${1:?Usage: install-opencode.sh VERSIONS_FILE}
# shellcheck source=/dev/null
source "$versions_file"

required_variables=(
  OPENCODE_VERSION
  OPENCODE_SHA256
)
for variable in "${required_variables[@]}"; do
  if [[ -z ${!variable:-} ]]; then
    echo "Missing OpenCode metadata: $variable" >&2
    exit 1
  fi
done

readonly archive=/tmp/opencode-desktop.rpm

curl -fL -o "$archive" \
  "https://opencode.ai/files/bin/${OPENCODE_VERSION}/opencode-desktop-linux-x86_64.rpm"
echo "${OPENCODE_SHA256}  ${archive}" | sha256sum -c -
# Silverblue links /opt to var/opt, whose target is absent in the base image.
mkdir -p /var/opt
dnf5 install -y "$archive"

# bootc unpacks /var only from the initial image, so upgrades would never deliver
# the application there. Ship it in /usr; tmpfiles restores the /opt/OpenCode path.
mv /var/opt/OpenCode /usr/lib/opencode
rmdir /var/opt

rm -f "$archive"
dnf5 clean all
