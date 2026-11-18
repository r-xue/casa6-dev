# Pixi Tasks Reference

All commands configured in [`pixi.toml`](https://github.com/r-xue/casa6-dev/blob/main/pixi.toml) that you can run with `pixi run <task>`.

---

## Build Tasks

| Task | What it runs | Description |
| :--- | :--- | :--- |
| `clone-repo` | `bash build-scripts/clone-repo.sh` | Clones CASA 6 with submodules and applies patches. |
| `clone-dev` | `CASA_DEVELOPMENT_MODE=true ...` | Updates source without resetting your local working tree. |
| `update-submodules` | `cd src/casa6 && git submodule update --recursive` | Updates CASA 6 git submodules. |
| `build-libsakura` | `bash build-scripts/build-libsakura.sh` | Builds `libsakura` (optional/legacy helper). |
| `build-casacore` | `bash build-scripts/build-casacore.sh` | Builds casacore with FFTPack. |
| `build-hpg` | `bash build-scripts/build-hpg.sh` | Builds HPG with CUDA and OpenMP (when `CASA_ENABLE_GPU=1`). |
| `build-casacpp` | `bash build-scripts/build-casacpp.sh` | Builds core CASA C++ libraries. |
| `build-casatools` | `bash build-scripts/build-casatools.sh` | Generates SWIG bindings and builds the `casatools` wheel. |
| `build-casatasks` | `bash build-scripts/build-casatasks.sh` | Packages the `casatasks` wheel. |
| `build-all` | Task chain | Runs `clone-repo` through `build-casatasks` in order. |
| `build-dev` | Task chain | Same as `build-all`, using `clone-dev` to preserve local edits. |

---

## Shortcut Build Targets

| Task | Target Environment |
| :--- | :--- |
| `build-linux` | Linux x86_64 CPU (Python 3.12) |
| `build-linux-311` / `312` / `313` | Linux x86_64 CPU (Python 3.11 / 3.12 / 3.13) |
| `build-gpu` | Linux x86_64 CUDA GPU (Python 3.12) |
| `build-gpu-312` / `313` / `314` | Linux x86_64 CUDA GPU (Python 3.12 / 3.13 / 3.14) |
| `build-mpi` | Linux x86_64 OpenMPI (Python 3.12) |
| `build-gpu-mpi` | Linux x86_64 CUDA GPU + OpenMPI (Python 3.12) |
| `build-gpu-mpi-314` | Linux x86_64 CUDA GPU + OpenMPI (Python 3.14) |
| `build-arm` | macOS Apple Silicon (Python 3.12) |
| `build-arm-311` / `312` / `313` | macOS Apple Silicon (Python 3.11 / 3.12 / 3.13) |
| `build-intel` | macOS Intel (Python 3.12) |
| `build-intel-311` / `312` / `313` | macOS Intel (Python 3.11 / 3.12 / 3.13) |

---

## Workspace & Cache Tasks

| Task | Command | Description |
| :--- | :--- | :--- |
| `clean` | Shell script | Removes build folders and object files. |
| `clean-protobuf` | Shell script | Removes generated protobuf build directories. |
| `clean-all` | Shell script | Wipes build folders, output wheels, and compiler cache. |
| `ccache-stats` | `ccache -d tmp/ccache --show-stats` | Shows compiler cache hit rate and size. |
| `ccache-cleanup` | `ccache -d tmp/ccache --cleanup` | Reclaims cache space to stay within `CCACHE_MAXSIZE`. |
| `ccache-clear` | `ccache -d tmp/ccache --clear` | Empties the compiler cache. |
| `test` | `python -m pytest tests/` | Runs pytest (requires a local `tests/` directory). |
| `docs-build` | `pixi exec --spec zensical zensical build --clean` | Builds static documentation site into `site/`. |
| `docs-serve` | `pixi exec --spec zensical zensical serve` | Starts local live-reload documentation server. |
