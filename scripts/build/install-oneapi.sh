#!/usr/bin/env bash
set -Eeuo pipefail

readonly versions_file=${1:?Usage: install-oneapi.sh VERSIONS_FILE}
# shellcheck source=/dev/null
source "$versions_file"

required_variables=(
  ONEAPI_COMMON_VERSION
  ONEAPI_COMPILER_VERSION
  ONEAPI_UMF_VERSION
  ONEAPI_TBB_VERSION
  ONEAPI_TCM_VERSION
)
for variable in "${required_variables[@]}"; do
  if [[ -z ${!variable:-} ]]; then
    echo "Missing oneAPI metadata: $variable" >&2
    exit 1
  fi
done

readonly packages=(
  "intel-oneapi-common-licensing-${ONEAPI_COMMON_VERSION}"
  "intel-oneapi-common-oneapi-vars-${ONEAPI_COMMON_VERSION}"
  "intel-oneapi-common-vars-${ONEAPI_COMMON_VERSION}"
  "intel-oneapi-compiler-shared-runtime-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-openmp-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-openmp-common-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-umf-1.0-${ONEAPI_UMF_VERSION}"
  "intel-oneapi-tbb-2022.3-${ONEAPI_TBB_VERSION}"
  "intel-oneapi-tcm-1.4-${ONEAPI_TCM_VERSION}"
)

# Silverblue links /opt to var/opt, whose target is absent in the base image.
mkdir -p /var/opt
dnf5 install -y --enable-repo=oneAPI "${packages[@]}"

# bootc unpacks /var only from the initial image, so upgrades would never deliver
# the runtimes there. Ship them in /usr; tmpfiles restores the /opt/intel path.
mv /var/opt/intel /usr/lib/intel
rmdir /var/opt

# The compiler runtime registers its CPU OpenCL driver through /opt; point the
# ICD at /usr so it does not depend on the tmpfiles link.
sed -i 's|^/opt/intel/|/usr/lib/intel/|' /etc/OpenCL/vendors/intel64.icd
# The OpenMP scriptlet's /usr/local pkgconfig links fail harmlessly because
# /var/usrlocal is absent at build time; setvars.sh exports PKG_CONFIG_PATH.

dnf5 clean all
