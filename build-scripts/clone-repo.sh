#!/bin/bash
set -euo pipefail

# Helper function to retry network commands on transient failure
retry_cmd() {
    local -r max_attempts="${RETRY_MAX:-4}"
    local -r delay="${RETRY_DELAY:-5}"
    local attempt=1
    until "$@"; do
        if (( attempt >= max_attempts )); then
            echo "Error: Command '$*' failed after $max_attempts attempts." >&2
            return 1
        fi
        echo "Command '$*' failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..." >&2
        sleep "$delay"
        ((attempt++))
    done
}

# Fetch libsakura source if LIBSAKURA_URL is explicitly set
if [[ -n "${LIBSAKURA_URL:-}" ]]; then
    echo "Fetching libsakura from: $LIBSAKURA_URL"
    mkdir -p src
    (cd src && (retry_cmd curl -fsSL "${LIBSAKURA_URL}" | tar -zxf - || { echo "Download or extraction of libsakura failed"; exit 1; } ) )
else
    echo "LIBSAKURA_URL not set — using conda-installed libsakura (default)"
fi

echo "Cloning CASA6 repository..."

# Check for development mode flag
DEVELOPMENT_MODE=${CASA_DEVELOPMENT_MODE:-false}
SKIP_REMOTE_UPDATE=${CASA_SKIP_REMOTE_UPDATE:-false}

# Check for branch/tag specification (upstream default is 'master')
CASA_BRANCH=${CASA_BRANCH:-}
if [[ -z "$CASA_BRANCH" ]] && [[ -d "src/casa6/.git" ]]; then
    CASA_BRANCH=$(cd src/casa6 && git branch --show-current 2>/dev/null || echo "")
fi
CASA_BRANCH=${CASA_BRANCH:-master}
echo "Using CASA_BRANCH: $CASA_BRANCH"

if [ ! -d "src" ]; then
    mkdir -p src
fi

cd src

if [ ! -d "casa6/.git" ]; then
    echo "Cloning fresh repository (blobless clone)..."
    rm -rf casa6
    retry_cmd git clone --filter=blob:none https://open-bitbucket.nrao.edu/scm/casa/casa6.git
    cd casa6
    
    # Checkout specified branch/tag if provided
    if [[ -n "$CASA_BRANCH" ]]; then
        echo "Checking out branch/tag: $CASA_BRANCH"
        git checkout "$CASA_BRANCH"
    fi

    echo "Initializing and updating git submodules..."
    retry_cmd git submodule update --init --recursive --jobs 4 --depth 1
    
    # Apply local patches after initial clone
    if [[ -f "../../patches/apply-patches.sh" ]]; then
        echo "Applying local patches..."
        bash ../../patches/apply-patches.sh
    fi
else
    cd casa6
    
    if [[ "$DEVELOPMENT_MODE" == "true" ]] || [[ "$SKIP_REMOTE_UPDATE" == "true" ]]; then
        echo "Development/Prepared mode: Skipping git update to preserve local changes"
        echo "Current git status:"
        git status --porcelain || echo "Not a git repository (local changes preserved)"
        
        # Still check submodules in development mode
        if [[ -d ".git" ]] && [[ ! -f "casatools/casacore/CMakeLists.txt" ]]; then
            echo "Submodules appear to be missing, updating them..."
            retry_cmd git submodule update --init --recursive --jobs 4 --depth 1
        fi
    else
        if [[ -d ".git" ]]; then
            echo "Repository exists, updating..."
            # Stash any local changes
            if ! git diff-index --quiet HEAD --; then
                echo "Stashing local changes..."
                git stash push -m "Auto-stash before update $(date)"
            fi
            if ! retry_cmd timeout 60s git fetch origin; then
                echo "::warning::Failed to fetch updates from Bitbucket; continuing with cached repository."
            else
                # Checkout and update to specified branch
                echo "Switching to branch/tag: $CASA_BRANCH"
                git checkout "$CASA_BRANCH"
                git reset --hard "origin/$CASA_BRANCH" 2>/dev/null || {
                    echo "Could not reset to origin/$CASA_BRANCH, assuming it's a tag or local branch"
                    git reset --hard "$CASA_BRANCH" 2>/dev/null || echo "Using current HEAD"
                }
            fi

            echo "Updating git submodules..."
            retry_cmd timeout 60s git submodule update --init --recursive --jobs 4 --depth 1 || {
                if [[ -f "casatools/casacore/CMakeLists.txt" ]]; then
                    echo "::warning::Submodule update failed; continuing with cached submodules."
                else
                    exit 1
                fi
            }
            
            # Apply local patches after update
            if [[ -f "../../patches/apply-patches.sh" ]]; then
                echo "Applying local patches..."
                bash ../../patches/apply-patches.sh
            fi
        else
            echo "No .git directory found - assuming development mode"
            echo "Skipping git update to preserve local modifications"
            
            # Check if we need submodules
            if [[ ! -f "casatools/casacore/CMakeLists.txt" ]]; then
                echo "ERROR: casacore submodule is missing and we can't update it without git!"
                echo "You'll need to either:"
                echo "1. Restore the .git directory and run with git tracking"
                echo "2. Manually download and extract casacore to casatools/casacore/"
                echo "3. Use a fresh clone with 'pixi run clean-all && pixi run -e intel-mac clone-repo'"
                exit 1
            fi
        fi
    fi
fi

echo "CASA6 repository ready at: $(pwd)"
echo "Current branch/commit:"
if [[ -d ".git" ]]; then
    echo "  Branch: $(git branch --show-current)"
    echo "  Commit: $(git rev-parse HEAD)"
    echo "Submodule status:"
    git submodule status
else
    echo "Local development copy (no git tracking)"
fi

# Verify critical submodules are present
if [[ -f "casatools/casacore/CMakeLists.txt" ]]; then
    echo "✓ casacore submodule is present"
else
    echo "✗ casacore submodule is MISSING - build will fail"
    exit 1
fi
