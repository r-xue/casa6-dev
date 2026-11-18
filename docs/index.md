# CASA6-Dev

!!! note "Credits & Upstream Origins"
    This project is built directly on [casa6-dev](https://github.com/schiebel/casa6-dev), created and authored by **[@schiebel](https://github.com/schiebel)** (also upstream CASA developer). Full credit to **[@schiebel](https://github.com/schiebel)** for establishing this Pixi and Conda-Forge workspace, configuring the macOS and Linux toolchains, authoring the core C++ compatibility and packaging patches, resolving modern Python 3.12+ integration, and making CASA 6 buildable in a modern developer environment. 
    
    This fork builds upon that foundation by adding automated multi-architecture CI, HPG GPU integration, and standalone binary wheel distribution.

**casa6-dev** is a Pixi-based workspace for building, patching, and packaging [CASA 6](https://open-bitbucket.nrao.edu/scm/casa/casa6.git).

It lets you compile CASA 6 with modern compilers and Python versions (3.12 to 3.14) on both Linux and macOS, adds optional GPU acceleration using HPG (High Performance Gridding), and packages self-contained binary wheels you can install with regular `pip`.

---

## What's Included

- **Platform support**:
    - **Linux x86_64**: Modern GCC toolchains, optional CUDA 12 and OpenMPI, plus compatibility aliases for RHEL 8 / Rocky 8.
    - **macOS Apple Silicon (`arm64`)**: Native M-series builds with LLVM OpenMP.
    - **macOS Intel (`x86_64`)**: Builds for older Intel Macs with linker workarounds for Xcode 16.
- **Python versions**:
    - Python **3.12** (default), **3.13**, and **3.14**.
- **GPU Gridding (HPG)**:
    - Supports the [High Performance Gridding (HPG)](https://gitlab.nrao.edu/mpokorny/hpg) library with CUDA and Kokkos.
    - Falls back to OpenMP CPU gridding automatically if no GPU or driver is found, or when forced via `HPGDEVICE=omp`.
- **Standalone Wheels**:
    - Wheels bundle required C++ libraries (`casatools.libs/` via `auditwheel` on Linux, `casatools.dylibs/` via `delocate` on macOS).
    - Includes a stub CUDA driver so wheels built with GPU support still import and run on machines without an NVIDIA GPU.
    - Nightly builds are published to GitHub Releases and served through a **PEP 503 pip index** on GitHub Pages.

---

## Documentation

=== "Design & Setup"
    - [Toolchain & Environments](design/toolchain.md): How Pixi, Conda packages, and CMake fit together.
    - [Patches & Fixes](design/patches.md): What upstream files are patched and why.

=== "How-To Guides"
    - [Building Locally](guides/building-locally.md): Step-by-step commands to build components or the full stack.
    - [GPU & HPG Acceleration](guides/gpu-and-hpg.md): Setting up CUDA, picking architectures, and switching devices at runtime.
    - [Standalone Wheels & Index](guides/wheels-and-index.md): How wheels are repaired and installed via pip.
    - [Troubleshooting](guides/troubleshooting.md): Fixes for common compiler, linker, and runtime errors.

=== "Reference"
    - [Pixi Tasks](reference/pixi-tasks.md): List of commands defined in `pixi.toml`.
    - [Environment Variables](reference/env-vars.md): Supported runtime and build flags (`HPGDEVICE`, `CASA_GPU_ARCH`, etc.).
