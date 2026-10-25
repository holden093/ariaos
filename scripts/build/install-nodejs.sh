#!/usr/bin/env bash
set -Eeuo pipefail

readonly versions_file=${1:?Usage: install-nodejs.sh VERSIONS_FILE}
# shellcheck source=/dev/null
source "$versions_file"

required_variables=(
  NODEJS_VERSION
  NODEJS_SHA256
)
for variable in "${required_variables[@]}"; do
  if [[ -z ${!variable:-} ]]; then
    echo "Missing Node.js metadata: $variable" >&2
    exit 1
  fi
done

readonly archive=/tmp/nodejs.tar.xz
readonly install_dir=/usr/lib/nodejs

curl -fL -o "$archive" \
  "https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-x64.tar.xz"
echo "${NODEJS_SHA256}  ${archive}" | sha256sum -c -

rm -rf "$install_dir"
mkdir -p "$install_dir"
tar -xJf "$archive" -C "$install_dir" --strip-components=1 --no-same-owner

# Fails if a Fedora nodejs RPM already owns these paths.
for tool in node npm npx corepack; do
  ln -s "../lib/nodejs/bin/$tool" "/usr/bin/$tool"
done

rm -f "$archive"
