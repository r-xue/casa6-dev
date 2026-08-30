#!/bin/bash
set -euo pipefail

echo "Building HPG (High Performance Gridding)..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e linux-gpu build-hpg"
    exit 1
fi

if [[ "${CASA_ENABLE_GPU:-0}" != "1" ]]; then
    echo "GPU build not requested (CASA_ENABLE_GPU != 1). Skipping HPG build."
    exit 0
fi

# Set project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

mkdir -p "$PROJECT_ROOT/src"
cd "$PROJECT_ROOT/src"

if [ ! -d "hpg/.git" ]; then
    echo "Cloning HPG repository..."
    rm -rf hpg
    git clone https://gitlab.nrao.edu/mpokorny/hpg.git
fi

cd hpg

echo "Cleaning previous builds..."
rm -rf build
mkdir -p build
cd build

export CC="${CC:-gcc}"
export CXX="${CXX:-g++}"

# Configure wrapper to use the conda-provided C++ compiler as host
export NVCC_WRAPPER_DEFAULT_COMPILER="$CXX"

echo "Running CMake for HPG..."
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CXX_COMPILER="$CONDA_PREFIX/bin/nvcc_wrapper" \
    -DHPG_ENABLE_CUDA=ON \
    -DHPG_ENABLE_SERIAL=ON \
    -DHPG_ENABLE_OPENMP=ON \
    -DFFTW_ROOT_DIR="$CONDA_PREFIX" \
    -DFFTW_INCLUDE_DIR="$CONDA_PREFIX/include" \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    ..

echo "Building HPG..."
cmake --build . -j$(python3 -c 'import os; print(os.cpu_count() or 4)')

echo "Installing HPG into Conda prefix..."
cmake --install .

echo "HPG build and installation completed successfully!"

