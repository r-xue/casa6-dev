# Building Locally

This guide walks through compiling CASA 6 from source on your machine using Pixi.

---

## Prerequisites

- Install [Pixi](https://pixi.sh):
  ```bash
  curl -fsSL https://pixi.sh/install.sh | bash
  ```
- Make sure `git` and `bash` are available on your system.

---

## 1. Quick Start: Build Everything

Pick the command that matches your machine:

=== "Linux (CPU only)"
    ```bash
    pixi run -e linux-dev build-all
    ```

=== "Linux (GPU + CUDA 12)"
    ```bash
    pixi run --platform linux-64-cuda -e linux-gpu build-all
    ```

=== "macOS (Apple Silicon M1/M2/M3/M4)"
    ```bash
    pixi run -e arm-mac build-all
    ```

=== "macOS (Intel)"
    ```bash
    pixi run -e intel-mac build-all
    ```

The resulting wheels will be written to:
- `src/casa6/casatools/dist/casatools-*.whl`
- `src/casa6/casatasks/dist/casatasks-*.whl`

---

## 2. Building Parts Individually

When you are actively debugging or working on a single component, you don't need to rebuild the entire project from scratch. Run individual tasks using the **same** target environment consistently (for example `-e linux-dev` for CPU-only, or `--platform linux-64-cuda -e linux-gpu` for GPU—note that `build-casacpp` and `build-casatools` invoke `build-hpg` automatically when `CASA_ENABLE_GPU=1`):

```bash
# 1. Download or update CASA 6 source and apply patches
pixi run clone-repo

# 2. Build casacore (includes FFTPack)
pixi run -e linux-dev build-casacore

# 3. (Optional, GPU builds only) Build HPG with CUDA & OpenMP support
pixi run --platform linux-64-cuda -e linux-gpu build-hpg

# 4. Build the casacpp C++ library (use --platform linux-64-cuda -e linux-gpu for GPU)
pixi run -e linux-dev build-casacpp

# 5. Build casatools (SWIG bindings and wheel)
pixi run -e linux-dev build-casatools

# 6. Build the casatasks Python package
pixi run -e linux-dev build-casatasks
```

---

## 3. Cleaning Up

```bash
# Clean intermediate object files and CMake caches
pixi run clean

# Full reset (wipes build folders, output wheels, and compiler cache)
pixi run clean-all
```
