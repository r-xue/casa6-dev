#!/bin/bash
set -euo pipefail

echo "Building casacore with FFTPack support..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casacore"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6/casatools/casacore

# Create build directory
mkdir -p build
cd build

# Platform-specific configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific settings
    export CC="clang"
    export CXX="clang++"
    export FC=gfortran
    
    # Set OpenMP flags for macOS
    export CPPFLAGS="-I$CONDA_PREFIX/include ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    # macOS-specific compiler flags
    export CXXFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CXXFLAGS:-}"
    export CFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CFLAGS:-}"
    
    # Additional macOS CMake flags
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=gfortran -DOpenMP_ROOT=$CONDA_PREFIX"
    
else
    # Linux specific settings
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    export FC="${FC:-gfortran}"
    export CPPFLAGS="-I$CONDA_PREFIX/include ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=$FC -DCMAKE_Fortran_FLAGS=-fallow-argument-mismatch"
fi

# ccache configuration
export CCACHE_DIR="$PROJECT_ROOT/tmp/ccache"
export CCACHE_MAXSIZE="15G"
export CCACHE_COMPRESS=1
export CCACHE_BASEDIR="$PROJECT_ROOT"
export CCACHE_NOHASHDIR=1

# Initialize ccache directory and show stats
echo "Setting up ccache..."
mkdir -p "$CCACHE_DIR"
ccache --max-size="$CCACHE_MAXSIZE"
ccache --set-config=compression=true
echo "ccache statistics before build:"
ccache --show-stats

echo "Compiler settings:"
echo "  CC=$CC"
echo "  CXX=$CXX"
echo "  FC=$FC"
echo "  CPPFLAGS=$CPPFLAGS"
echo "  LDFLAGS=$LDFLAGS"
echo "  CCACHE_DIR=$CCACHE_DIR"
echo "  CCACHE_MAXSIZE=$CCACHE_MAXSIZE"

# Testing toggle (default: false / disabled for fast builds)
# Can be enabled via environment variable: CASA_BUILD_TESTS=true or BUILD_TESTING=true/ON
BUILD_TESTS="${CASA_BUILD_TESTS:-${BUILD_TESTING:-false}}"
if [[ "$BUILD_TESTS" == "true" || "$BUILD_TESTS" == "TRUE" || "$BUILD_TESTS" == "ON" || "$BUILD_TESTS" == "1" ]]; then
    CMAKE_TEST_FLAGS="-DBUILD_TESTING=ON -DBUILD_APPS=ON"
    echo "C++ testing: ENABLED"
else
    CMAKE_TEST_FLAGS="-DBUILD_TESTING=OFF -DBUILD_APPS=OFF"
    echo "C++ testing: DISABLED (set CASA_BUILD_TESTS=true to enable)"
fi

# Configure casacore with CMake
echo "Configuring casacore with CMake..."
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=14 \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$CONDA_PREFIX" \
    -DBUILD_FFTPACK_DEPRECATED=YES \
    -DBUILD_PYTHON=OFF \
    -DBUILD_PYTHON3=OFF \
    -DUSE_OPENMP=ON \
    -DUSE_THREADS=ON \
    -DBoost_NO_BOOST_CMAKE=ON \
    $CMAKE_TEST_FLAGS \
    $CMAKE_EXTRA_FLAGS

# Build
echo "Building casacore in parallel..."
cmake --build . --parallel

# Install
echo "Installing casacore..."
cmake --build . --target install

echo "casacore build completed successfully!"
echo "FFTPack should now be available for casacpp build."
