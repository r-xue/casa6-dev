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

# Set GPU architecture if provided
CMAKE_EXTRA_CXX_FLAGS=""
if [[ -n "${CASA_GPU_ARCH:-}" ]]; then
    echo "Targeting GPU architecture: ${CASA_GPU_ARCH}"
    CMAKE_EXTRA_CXX_FLAGS="-arch=${CASA_GPU_ARCH}"
fi

echo "Running CMake for HPG..."
cmake \
    -DCMAKE_CXX_FLAGS="${CMAKE_EXTRA_CXX_FLAGS}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_CXX_COMPILER="$CONDA_PREFIX/bin/nvcc_wrapper" \
    -DHPG_ENABLE_CUDA=ON \
    -DHPG_ENABLE_SERIAL=ON \
    -DHPG_ENABLE_OPENMP=ON \
    -DFFTW_ROOT_DIR="$CONDA_PREFIX" \
    -DFFTW_INCLUDE_DIR="$CONDA_PREFIX/include" \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DHpg_BUILD_TESTS=OFF \
    ..

echo "Building HPG..."
cmake --build . -j$(python3 -c 'import os; print(os.cpu_count() or 4)')

echo "Installing HPG into Conda prefix..."
cmake --install .

echo "Creating compatibility symlink for hpg_indexing.hpp..."
ln -sf indexing.hpp "$CONDA_PREFIX/include/hpg/hpg_indexing.hpp"

echo "Adding backward-compatibility typedefs to hpg.hpp..."
cat << 'EOF' >> "$CONDA_PREFIX/include/hpg/hpg.hpp"

// Compatibility typedefs for CASA6
namespace hpg {
  using cf_fp = cf_fp_t;
  using visibility_fp = vis_fp_t;
  using grid_value_fp = grid_fp_t;
  using grid_weight_fp = grid_fp_t;
  using vis_weight_fp = vis_fp_t;
  using vis_frequency_fp = freq_fp_t;
  using vis_phase_fp = phase_fp_t;
  using vis_uvw_fp = uvw_fp_t;
  using cf_phase_gradient_fp = phase_fp_t;
}
EOF

echo "HPG build and installation completed successfully!"


echo "Creating CMake compatibility wrapper for CASA (Hpg -> hpg)..."
CMAKE_HPG_DIR="$CONDA_PREFIX/lib/cmake/hpg"
mkdir -p "$CMAKE_HPG_DIR"
cat << 'CMAKE_EOF' > "$CMAKE_HPG_DIR/hpgConfig.cmake"
# Compatibility wrapper for CASA 6 which expects 'hpg' instead of 'Hpg'
include("${CMAKE_CURRENT_LIST_DIR}/HpgConfig.cmake")
set(hpg_FOUND ${Hpg_FOUND})
if(TARGET Hpg::hpg AND NOT TARGET hpg::hpg)
    add_library(hpg::hpg ALIAS Hpg::hpg)
endif()
CMAKE_EOF
echo "Compatibility wrapper created at $CMAKE_HPG_DIR/hpgConfig.cmake"
