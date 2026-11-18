# Standalone Wheels & Pip Repository

When you first compile `casatools`, the resulting wheel links to dynamic libraries inside your Conda or Pixi environment (`libgfortran`, `libfftw3`, `libomp`, etc.).

To distribute wheels that install cleanly on any system without requiring Conda or Pixi, our release workflow repairs and bundles those libraries into the wheels.

---

## 1. How Wheel Bundling Works

- **Linux (`auditwheel`)**:
    - Copies required shared C/C++ libraries into a `casatools.libs/` directory inside the wheel.
    - Leaves `libcuda.so.1` out so the wheel uses the host system's real NVIDIA driver when available.
    - Creates a `manylinux_2_28_x86_64` compatibility alias so standard pip on RHEL 8 / Rocky 8 can install it.
- **macOS (`delocate`)**:
    - Vendors all dynamic libraries into `casatools.dylibs/`.
    - Rewrites library load paths (`rpath`) so the wheel works on macOS 14+ without system dependencies.

---

## 2. The Pip Repository (`/simple/`)

Every nightly build runs [`build-scripts/build_pip_index.py`](https://github.com/r-xue/casa6-dev/blob/main/build-scripts/build_pip_index.py) to generate a standard [PEP 503](https://peps.python.org/pep-0503/) repository hosted on GitHub Pages:

- **Repository index**: `https://www.magclouds.org/casa6-dev/simple/` (mirror of `https://r-xue.github.io/casa6-dev/simple/`)
- Direct wheel links point to GitHub Release assets with SHA256 integrity hashes.

---

## 3. How to Install

=== "Using standard pip"
    ```bash
    pip install --extra-index-url https://www.magclouds.org/casa6-dev/simple/ casatools casatasks
    ```

=== "Using Pixi"
    Add this to your `pixi.toml`:
    ```toml
    [dependencies]
    python = "3.12.*"  # or 3.13.*, 3.14.*

    [pypi-dependencies]
    casatools = { version = ">=6.8.0", index = "https://www.magclouds.org/casa6-dev/simple" }
    casatasks = { version = ">=6.8.0", index = "https://www.magclouds.org/casa6-dev/simple" }
    casashell = { version = ">=6.7.6", index = "https://casa-pip.nrao.edu/repository/pypi-group/simple" }
    ```

=== "Using uv"
    ```bash
    uv pip install --extra-index-url https://www.magclouds.org/casa6-dev/simple/ casatools casatasks
    ```
