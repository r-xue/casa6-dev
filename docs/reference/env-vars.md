# Environment Variables Reference

Environment variables used during builds and at runtime.

---

## Runtime Settings

| Variable | Example Values | Description |
| :--- | :--- | :--- |
| `HPGDEVICE` | `cuda`, `omp`, `serial` | Controls which device HPG uses for gridding. Set `HPGDEVICE=omp` to force CPU multi-threading even on a machine with a GPU. |
| `OMP_NUM_THREADS` | `4`, `8`, `16` | Number of CPU threads used by OpenMP for math and gridding routines. |
| `CUDA_VISIBLE_DEVICES` | `0`, `1`, or `""` | Standard NVIDIA flag to hide GPUs from the process. |
| `CASASITECONFIG` | Path to python file | Path to custom CASA site configuration file (useful to set `measurespath` or disable auto-updates). |

---

## Build Settings

| Variable | Example Values | Description |
| :--- | :--- | :--- |
| `CASA_ENABLE_GPU` | `0` or `1` | Turn GPU gridding support on or off when building. |
| `CASA_GPU_ARCH` | `sm_70`, `sm_80`, `sm_86`, `sm_89`, `sm_90` | Target NVIDIA GPU architecture passed to nvcc (default `sm_80`). |
| `CASA_BUILD_TYPE` | `Release`, `RelWithDebInfo`, `Debug` | CMake build configuration for `casacpp` and `casatools` (default `Release`). |
| `CASA_BUILD_TESTS` | `true` or `false` | Enable building C++ tests/apps in `casacore` (`BUILD_TESTING` is also accepted; default `false`). |
| `CASA_BRANCH` | `master` | Git branch or tag to fetch from upstream CASA 6. |
| `CASA_DEVELOPMENT_MODE` | `true` or `false` | When `true`, prevents `clone-repo` from resetting uncommitted local edits in `src/casa6`. |
| `CASA_SKIP_REMOTE_UPDATE`| `true` or `false` | Skips `git fetch` in CI when source code was already restored from cache. |
| `HPG_REMOTE` | Git URL | Override HPG git remote (default `https://gitlab.nrao.edu/mpokorny/hpg.git`). |
| `HPG_BRANCH` | `main` | Git branch or tag to clone for HPG (default `main`). |
| `CCACHE_MAXSIZE` | `2G`, `800M` | Maximum disk size for the compiler cache. |
