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
  ONEAPI_DEBUGGER_VERSION
  ONEAPI_DEV_UTILITIES_VERSION
  ONEAPI_DPL_VERSION
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
  "intel-oneapi-compiler-dpcpp-cpp-runtime-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-openmp-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-openmp-common-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-umf-1.0-${ONEAPI_UMF_VERSION}"
  "intel-oneapi-tbb-2022.3-${ONEAPI_TBB_VERSION}"
  "intel-oneapi-tcm-1.4-${ONEAPI_TCM_VERSION}"

  # DPC++/C++ compiler and its full dependency closure, pinned explicitly.
  "intel-oneapi-compiler-dpcpp-cpp-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-dpcpp-cpp-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-compiler-dpcpp-cpp-common-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-compiler-shared-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-compiler-shared-common-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-compiler-cpp-eclipse-cfg-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-compiler-dpcpp-eclipse-cfg-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-icc-eclipse-plugin-cpp-2025.3-${ONEAPI_COMPILER_VERSION}"
  "intel-oneapi-dpcpp-debugger-2025.3-${ONEAPI_DEBUGGER_VERSION}"
  "intel-oneapi-dev-utilities-2025.3-${ONEAPI_DEV_UTILITIES_VERSION}"
  "intel-oneapi-dev-utilities-eclipse-cfg-2025.3-${ONEAPI_DEV_UTILITIES_VERSION}"
  "intel-oneapi-tbb-devel-2022.3-${ONEAPI_TBB_VERSION}"
  "intel-oneapi-libdpstd-devel-2022.10-${ONEAPI_DPL_VERSION}"
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
# The OpenMP, TBB and oneDPL scriptlets' /usr/local pkgconfig links fail harmlessly because
# /var/usrlocal is absent at build time; setvars.sh exports PKG_CONFIG_PATH.

dnf5 clean all
