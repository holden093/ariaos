#!/usr/bin/env bash
set -euo pipefail

# ariaos-preflight — mandatory local build check before pushing
# Run from the repo root: ./skills/ariaos-preflight/scripts/preflight.sh

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BOLD='\033[1m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
CONTAINERFILE="$REPO_ROOT/Containerfile"
BUILD_FILES="$REPO_ROOT/build_files"

echo -e "${BOLD}🔍 AriaOS Preflight Check${NC}"
echo "   Repo: $REPO_ROOT"
echo

# 1. Check if there are uncommitted changes to Containerfile or build_files
if git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null | grep -qE "^(Containerfile|build_files/)"; then
    echo -e "   ${YELLOW}⚠ Uncommitted changes detected:${NC}"
    git -C "$REPO_ROOT" diff --name-only HEAD | grep -E "^(Containerfile|build_files/)" | sed 's/^/     /'
    echo
else
    echo -e "   ${GREEN}✅ No uncommitted changes to Containerfile or build_files/${NC}"
    echo
fi

# 2. Check if the Containerfile exists
if [ ! -f "$CONTAINERFILE" ]; then
    echo -e "   ${RED}❌ Containerfile not found at $CONTAINERFILE${NC}"
    exit 1
fi

# 3. Run the build
echo -e "   ${BOLD}🔨 Building with podman...${NC}"
echo

START_TIME=$(date +%s)

if podman build -f "$CONTAINERFILE" -t ariaos-preflight-test "$REPO_ROOT"; then
    DURATION=$(( $(date +%s) - START_TIME ))
    echo
    echo -e "   ${GREEN}${BOLD}✅ BUILD PASSED${NC} (${DURATION}s)"

    # 4. Quick smoke test: verify the rebuilt freerdp-libs is in the image
    echo -e "   ${BOLD}📦 Verifying packages...${NC}"
    FREERDP_VER=$(podman run --rm ariaos-preflight-test rpm -q freerdp-libs 2>/dev/null || echo "MISSING")
    if echo "$FREERDP_VER" | grep -q "ariaos"; then
        echo -e "     ${GREEN}freerdp-libs: $FREERDP_VER ✅${NC}"
    else
        echo -e "     ${YELLOW}freerdp-libs: $FREERDP_VER (not the custom build?)${NC}"
    fi

    # Clean up test image
    podman rmi ariaos-preflight-test >/dev/null 2>&1 || true

    echo
    echo -e "   ${GREEN}${BOLD}✅ PREFLIGHT COMPLETE — safe to push${NC}"
    exit 0
else
    DURATION=$(( $(date +%s) - START_TIME ))
    echo
    echo -e "   ${RED}${BOLD}❌ BUILD FAILED${NC} (${DURATION}s)"
    echo -e "   ${RED}DO NOT PUSH. Fix the build error first.${NC}"
    exit 1
fi
