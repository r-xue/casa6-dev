#!/bin/bash
set -euo pipefail

echo "Building casacpp (C++ libraries)..."

# Check that we're in a pixi/conda environment
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    echo "Error: CONDA_PREFIX not set. Make sure you're running this within a pixi environment."
    echo "Try: pixi run -e intel-mac build-casacpp"
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Project root: $PROJECT_ROOT"
echo "Using conda environment: $CONDA_PREFIX"

cd src/casa6

# The C++ code is now built as part of casatools
# Let's look for the correct CMakeLists.txt location
if [[ -d "casatools/src/code" ]]; then
    CASACPP_SOURCE_DIR="casatools/src/code"
    echo "Found casacpp source in: $CASACPP_SOURCE_DIR"
elif [[ -d "casatools/src" ]]; then
    CASACPP_SOURCE_DIR="casatools/src"
    echo "Found casacpp source in: $CASACPP_SOURCE_DIR"
elif [[ -d "casatools" ]]; then
    CASACPP_SOURCE_DIR="casatools"
    echo "Found casacpp source in: $CASACPP_SOURCE_DIR"
else
    echo "Error: Cannot find casacpp source directory"
    echo "Available directories in src/casa6:"
    ls -la
    exit 1
fi

# Create build directory
mkdir -p build/casacpp
cd build/casacpp

# Platform-specific configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific settings
    export CC="clang"
    export CXX="clang++"
    export FC=gfortran  # Set Fortran compiler
    
    # Set OpenMP flags for macOS (handle unset variables properly)
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$(pwd)/../../casatools ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    # macOS-specific compiler flags to handle deprecation warnings
    export CXXFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CXXFLAGS:-}"
    export CFLAGS="-Wno-error=deprecated-declarations -Wno-deprecated-declarations ${CFLAGS:-}"
    
    # CMake flags - let CMake use environment variables for compilers
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=gfortran -DOpenMP_ROOT=$CONDA_PREFIX"
    
    # Add flags to handle warnings as warnings, not errors
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_CXX_FLAGS=-Wno-error=deprecated-declarations -DCMAKE_C_FLAGS=-Wno-error=deprecated-declarations"

    # RPATH handling (macOS / Mach-O).
    # casacpp's .dylibs install flat into $CONDA_PREFIX/lib, so a library's
    # sibling dependencies live in the same directory as itself -- hence
    # plain @loader_path (not @loader_path/../lib). @loader_path is Mach-O's
    # relative-to-the-loading-binary token, the macOS analog of ELF's
    # $ORIGIN used in the Linux branch below.
    #
    # NOTE: this alone is not sufficient. casacore/CMakeLists.txt,
    # casatools/src/tools/CMakeLists.txt, and casatools/src/code/CMakeLists.txt
    # all contain a plain (non-CACHE) set(CMAKE_INSTALL_NAME_DIR
    # "${CMAKE_INSTALL_PREFIX}/lib") which silently shadows whatever we pass
    # here on the command line, so every target still ends up with an
    # absolute LC_ID_DYLIB regardless of this flag. See
    # fix-install-name-dir.sh (run automatically as a dependency of this
    # task) for the actual fix -- these CMAKE_INSTALL_RPATH/BUILD_WITH_
    # INSTALL_RPATH settings are what let the corrected @rpath-based install
    # names actually resolve at runtime, but they don't do anything on
    # their own while the CMakeLists.txt override is still in place.
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_MACOSX_RPATH=ON"
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_INSTALL_RPATH=@loader_path;$CONDA_PREFIX/lib"
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_INSTALL_NAME_DIR=@rpath"

else
    # Linux specific settings
    export CC="${CC:-gcc}"
    export CXX="${CXX:-g++}"
    export FC="${FC:-gfortran}"
    export CPPFLAGS="-I$CONDA_PREFIX/include -I$(pwd)/../../casatools ${CPPFLAGS:-}"
    export LDFLAGS="-L$CONDA_PREFIX/lib ${LDFLAGS:-}"
    
    CMAKE_EXTRA_FLAGS="-DCMAKE_Fortran_COMPILER=$FC -DCMAKE_Fortran_FLAGS=-fallow-argument-mismatch"

    # RPATH handling (Linux / ELF).
    # $ORIGIN is the ELF equivalent of Mach-O's @loader_path above. Note
    # CMAKE_MACOSX_RPATH and CMAKE_INSTALL_NAME_DIR are Mach-O-only concepts
    # and are intentionally omitted here. $ORIGIN must be escaped (\$ORIGIN)
    # so bash doesn't try to expand it as an (empty) shell variable before
    # cmake ever sees it.
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_INSTALL_RPATH=\$ORIGIN/../lib:$CONDA_PREFIX/lib"
    CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
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
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  CXXFLAGS=$CXXFLAGS"
    echo "  CFLAGS=$CFLAGS"
fi
echo "  Source directory: ../../$CASACPP_SOURCE_DIR"

# Testing toggle (default: false / disabled for fast builds)
# Can be enabled via environment variable: CASA_BUILD_TESTS=true or BUILD_TESTING=true/ON
BUILD_TESTS="${CASA_BUILD_TESTS:-${BUILD_TESTING:-false}}"
if [[ "$BUILD_TESTS" == "true" || "$BUILD_TESTS" == "TRUE" || "$BUILD_TESTS" == "ON" || "$BUILD_TESTS" == "1" ]]; then
    CMAKE_TEST_FLAGS="-DBUILD_TESTING=ON"
    echo "C++ testing: ENABLED"
else
    CMAKE_TEST_FLAGS="-DBUILD_TESTING=OFF -DCMAKE_PROJECT_casacpp_INCLUDE=$PROJECT_ROOT/build-scripts/cmake/casacpp-no-tests.cmake"
    echo "C++ testing: DISABLED (set CASA_BUILD_TESTS=true to enable)"
fi

# Configure with CMake
echo "Configuring with CMake..."
cmake ../../$CASACPP_SOURCE_DIR \
    -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_OPENMP=ON \
    -DUSE_THREADS=ON \
    -DCMAKE_CXX_STANDARD=14 \
    -DUseCrashReporter=OFF \
    -DBoost_NO_BOOST_CMAKE=ON \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$CONDA_PREFIX" \
    -DCMAKE_INCLUDE_PATH="$CONDA_PREFIX/include;$(pwd)/../../casatools" \
    $CMAKE_TEST_FLAGS \
    $CMAKE_EXTRA_FLAGS

# Build
echo "Building casacpp in parallel..."
cmake --build . --parallel

# Install
echo "Installing casacpp..."
cmake --build . --target install

echo "ccache statistics after build:"
ccache --show-stats

echo "casacpp build completed successfully!"
