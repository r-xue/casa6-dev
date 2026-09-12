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
#   HPG_OPTIONAL: If true, failure to clone will warn instead of failing
#   HPG_TIMEOUT: Per-attempt git clone timeout (default: 60s)
#   HPG_RETRIES: Maximum clone attempts (default: 3)

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
HPG_DIR="${PROJECT_ROOT}/src/hpg"
HPG_REMOTE="${HPG_REMOTE:-https://gitlab.nrao.edu/mpokorny/hpg.git}"
HPG_BRANCH="${HPG_BRANCH:-main}"
SKIP_REMOTE_UPDATE="${CASA_SKIP_REMOTE_UPDATE:-false}"
HPG_OPTIONAL="${HPG_OPTIONAL:-false}"
HPG_TIMEOUT="${HPG_TIMEOUT:-60s}"
HPG_RETRIES="${HPG_RETRIES:-3}"

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
for (( attempt=1; attempt<=HPG_RETRIES; attempt++ )); do
    echo "Attempt ${attempt}/${HPG_RETRIES}: cloning HPG..."
    rm -rf "${HPG_DIR}"
    if timeout "${HPG_TIMEOUT}" git clone --depth 1 --branch "${HPG_BRANCH}" \
        "${HPG_REMOTE}" "${HPG_DIR}"; then
        CLONED=1
        break
    fi
    echo "Attempt ${attempt} failed. Retrying in 5 seconds..."
    sleep 5
done

if [[ "${CLONED}" -ne 1 ]]; then
    rm -rf "${HPG_DIR}"
    if [[ "${HPG_OPTIONAL}" == "true" ]]; then
        echo "::warning::Failed to clone HPG from ${HPG_REMOTE}. Continuing without HPG (GPU builds may fail if HPG is required)."
        exit 0
    fi
    echo "Error: Failed to clone HPG from ${HPG_REMOTE} after ${HPG_RETRIES} attempts." >&2
    exit 1
fi

echo "HPG source cloned successfully into ${HPG_DIR}."
