#!/bin/bash
set -euo pipefail

echo "Building casatools..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casatools"
    exit 1
fi

# Set project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6/casatools

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/ dist/ *.egg-info/

# Set environment variables
export CASACPP_ROOT="$CONDA_PREFIX"
export CASA_BUILD_TYPE="Release"
export PKG_CONFIG_PATH="$CONDA_PREFIX/lib/pkgconfig:$CONDA_PREFIX/share/pkgconfig:${PKG_CONFIG_PATH:-}"
export CMAKE_PREFIX_PATH="$CONDA_PREFIX:${CMAKE_PREFIX_PATH:-}"
export CMAKE_BUILD_PARALLEL_LEVEL=$(python3 -c 'import os; print(os.cpu_count() or 4)')

# ccache configuration - use project-wide ccache directory
export CCACHE_DIR="$PROJECT_ROOT/tmp/ccache"
export CCACHE_MAXSIZE="15G"
export CCACHE_COMPRESS=1
export CCACHE_BASEDIR="$PROJECT_ROOT"
export CCACHE_NOHASHDIR=1

NUMPY_INCLUDE=`python -c 'import numpy as np; print(np.get_include())'`
# Platform-specific compiler settings
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CC="clang"
    export CXX="clang++"
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$NUMPY_INCLUDE ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    export CXXFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CXXFLAGS:-}"
    export CFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CFLAGS:-}"
else
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$NUMPY_INCLUDE ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
fi

# Initialize ccache directory and show stats
echo "Setting up ccache..."
mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"
ccache --set-config=compression=true
echo "ccache statistics before build:"
ccache --show-stats

echo "Build environment:"
echo "  CASACPP_ROOT=$CASACPP_ROOT"
echo "  CASA_BUILD_TYPE=$CASA_BUILD_TYPE"
echo "  CMAKE_BUILD_PARALLEL_LEVEL=$CMAKE_BUILD_PARALLEL_LEVEL"
echo "  CC=$CC"
echo "  CXX=$CXX"
echo "  CCACHE_DIR=$CCACHE_DIR"
echo "  CFLAGS=$CFLAGS"
echo "  CXXFLAGS=$CXXFLAGS"
echo "  CPPFLAGS=$CPPFLAGS"
echo "  LDFLAGS=$LDFLAGS"

# Build casatools wheel
echo "Building casatools wheel..."
python setup.py bdist_wheel

# Install the wheel
echo "Installing casatools wheel..."
pip install dist/*.whl --force-reinstall --no-deps

echo "ccache statistics after build:"
ccache --show-stats

echo "casatools build completed successfully!"
