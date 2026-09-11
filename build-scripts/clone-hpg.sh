#!/bin/bash
set -euo pipefail

# clone-hpg.sh — Clone or update the HPG source repository.
#
# Usage:
#   bash build-scripts/clone-hpg.sh
#
# Environment variables:
#   HPG_REMOTE: Remote repository URL
#               (default: https://gitlab.nrao.edu/mpokorny/hpg.git)
#   HPG_BRANCH: Branch or tag to clone (default: main)
#   CASA_SKIP_REMOTE_UPDATE: If true and src/hpg/.git exists,
#                            skip all network operations

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
HPG_DIR="${PROJECT_ROOT}/src/hpg"
HPG_REMOTE="${HPG_REMOTE:-https://gitlab.nrao.edu/mpokorny/hpg.git}"
HPG_BRANCH="${HPG_BRANCH:-main}"
SKIP_REMOTE_UPDATE="${CASA_SKIP_REMOTE_UPDATE:-false}"

mkdir -p "${PROJECT_ROOT}/src"

if [[ -d "${HPG_DIR}/.git" ]]; then
    echo "HPG source already exists at ${HPG_DIR}."
    if [[ "${SKIP_REMOTE_UPDATE}" == "true" ]]; then
        echo "CASA_SKIP_REMOTE_UPDATE is true — skipping remote update."
        exit 0
    fi
    echo "HPG repository present. Skipping re-clone."
    exit 0
fi

echo "Cloning HPG repository from ${HPG_REMOTE} (branch: ${HPG_BRANCH})..."

CLONED=0
for attempt in 1 2 3; do
    echo "Attempt ${attempt}/3: cloning HPG..."
    rm -rf "${HPG_DIR}"
    if timeout 60s git clone --depth 1 --branch "${HPG_BRANCH}" \
        "${HPG_REMOTE}" "${HPG_DIR}"; then
        CLONED=1
        break
    fi
    echo "Attempt ${attempt} failed. Retrying in 5 seconds..."
    sleep 5
done

if [[ "${CLONED}" -ne 1 ]]; then
    echo "Error: Failed to clone HPG from ${HPG_REMOTE} after 3 attempts." >&2
    exit 1
fi

echo "HPG source cloned successfully into ${HPG_DIR}."
