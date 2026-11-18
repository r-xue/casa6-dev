# Patches & Fixes

Upstream CASA 6 is maintained primarily for older Red Hat and CentOS releases. To get it building on modern toolchains (GCC 14–16, Clang 22), Python 3.12+, and recent CUDA releases, we keep a small set of patches in the `patches/` folder.

These are applied automatically by `patches/apply-patches.sh` whenever you run `clone-repo`.

The core C++ compatibility and packaging patches were originally investigated and authored by **[@schiebel](https://github.com/schiebel)** in [schiebel/casa6-dev](https://github.com/schiebel/casa6-dev).

---

## What Each Patch Does

### Core Compatibility & Packaging (by [@schiebel](https://github.com/schiebel))

| Patch Name | Component | What it fixes |
| :--- | :--- | :--- |
| `fix-unique-ptr-copy.patch` | `casacore` | Fixes illegal copy-construction of `std::unique_ptr` in casacore templates. |
| `casacore-visibilityprocessing-not_fn.patch` | `casacore` | Adds missing `std::not_fn` symbol definitions in visibility processing headers. |
| `casacore-remove-pipe.patch` / `casacpp-remove-pipe.patch` | `casacore` / `casacpp` | Drops the `-pipe` compiler flag, which exhausts assembler memory on macOS Sonoma. |
| `casatasks-copy-ignore-existing.patch` | `casatasks` | Ignores existing files when copying during packaging so it doesn't fail on rebuilds. |
| `casatools-builddir-fix.patch` | `casatools` | Fixes build directory path handling in setup scripts. |
| `casatools-wheel-libgcc-fix.patch` | `casatools` | Fixes bundling of `libgcc` inside wheel distributions. |

### Python 3.12+ & Modern C++17

| Patch Name | Component | What it fixes |
| :--- | :--- | :--- |
| `casatools-py312-swig-typemaps.patch` | `casatools` | Updates SWIG typemaps to support Python 3.12+ C-API changes. |
| `casatools-msmetadata-counting-iterator.patch` | `casatools` | Fixes `counting_iterator` comparison operator for C++17 and modern libc++. |

### HPG GPU Acceleration & Dynamic Fallback

| Patch Name | Component | What it fixes |
| :--- | :--- | :--- |
| `hpg-awvisresampler-segfault-fix.patch` | `casatools` | Fixes a silent crash when creating the HPG gridder, adds runtime fallback from CUDA to CPU (OpenMP or Serial), and adds `HPGDEVICE` support. |
| `casatools-cuda-stub-fallback.patch` | `casatools` | Bundles a dummy `libcuda.so` stub into wheels; if your machine has no NVIDIA GPU driver, it preloads the stub so Python import won't crash. |
| `casatools-hpg-clean-shutdown.patch` | `casatools` | Hooks into `std::atexit` to shut down HPG and Kokkos before the CUDA driver unloads, avoiding exit-time segfaults. |

---

## How to Edit or Add Patches

If you want to edit CASA 6 code locally without your changes being overwritten:

1. Turn on development mode:
   ```bash
   export CASA_DEVELOPMENT_MODE=true
   pixi run clone-dev
   ```
2. Edit your files inside `src/casa6/`.
3. Create a patch from your git diff:
   ```bash
   cd src/casa6
   git diff path/to/file > ../../patches/my-new-fix.patch
   ```
4. Add `my-new-fix.patch` to `patches/apply-patches.sh`.
