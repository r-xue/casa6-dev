# Troubleshooting

Common issues when building or running CASA 6 and how to resolve them.

---

## 1. RHEL 8 / Rocky 8: `GLIBCXX_3.4.29 not found`

### Problem
When importing `casatools` on an Enterprise Linux 8 machine:
```
ImportError: /lib64/libstdc++.so.6: version `GLIBCXX_3.4.29' not found
```

### Why it happens
The default system GCC on RHEL 8 is GCC 8.5.0, which only provides `GLIBCXX` up to `3.4.25`. CASA 6 uses C++17 features that require `GLIBCXX_3.4.29`.

### How to fix it
- **Inside Conda or Pixi**: This is automatic. Conda environments ship their own newer `libstdc++.so.6`.
- **On an HPC cluster**: Load a newer GCC module (GCC 11 or higher) before starting Python:
  ```bash
  module load gcc/11
  python -c "import casatools"
  ```

---

## 2. macOS: Xcode 16 Linker Error (`-lto_library`)

### Problem
During the build on macOS with Xcode 16 installed:
```
ld: unknown option: -lto_library /path/to/libLTO.dylib
```

### Why it happens
Conda-forge's Clang passes `-lto_library` with an absolute path. The newer Xcode 16 `ld-prime` linker rejects full paths for this option and expects only `libLTO.dylib`.

### How to fix it
We include a small wrapper script in [`build-scripts/wrappers/osx-64/ld`](https://github.com/r-xue/casa6-dev/blob/main/build-scripts/wrappers/osx-64/ld) that filters out this flag. Pixi activates it automatically in the `intel-mac` environment:
```toml
[target.osx-64.activation.env]
PATH = "$PIXI_PROJECT_ROOT/build-scripts/wrappers/osx-64:$PATH"
```

---

## 3. Headless Linux: `libGL.so.1` or Display Errors

### Problem
Running tests or scripts without a graphical desktop fails with:
```
libGL.so.1: cannot open shared object file: No such file or directory
```

### How to fix it
CASA GUI tools and plotms need an X11 display. On headless CI or server nodes, Linux Pixi environments include `pytest-xvfb`, or you can wrap commands with `xvfb-run`:
```bash
xvfb-run -a python -m pytest <path-to-tests>
```

---

## 4. CUDA Crash When Exiting (`atexit`)

### Problem
GPU gridding runs and completes fine, but Python segfaults right when the process exits.

### Why it happens
The CUDA driver was being unloaded while Kokkos and HPG still had active memory allocations.

### How to fix it
We patched this in [`patches/casatools-hpg-clean-shutdown.patch`](https://github.com/r-xue/casa6-dev/blob/main/patches/casatools-hpg-clean-shutdown.patch). It adds an `std::atexit` hook so HPG finishes cleaning up before the driver unloads.
