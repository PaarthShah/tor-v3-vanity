# Cross-compile to ARM64: what exists and how to install (Ubuntu/Debian)

The Makefile has two build targets: **`make amd64`** and **`make arm64`**. When you run `make arm64` on an amd64 host, it cross-compiles automatically (runs `scripts/setup-cross-arm64.sh` and uses `AARCH64_CUDA_LIB_DIR`, default `rust/cuda-arm64-libs`). You still need aarch64 CUDA libs for linking; see below.

## 1. Aarch64 cross-compiler (gcc + libc)

**Exists:** Yes, in Ubuntu and Debian.

| What | Package(s) | Repo |
|------|------------|------|
| GCC for aarch64 | `gcc-aarch64-linux-gnu` (meta) or `gcc-13-aarch64-linux-gnu` / `gcc-14-aarch64-linux-gnu` | Ubuntu: **universe**. Debian: main. |
| C library for aarch64 (needed by gcc cross) | `libc6-arm64-cross`, `libc6-dev-arm64-cross` | Ubuntu: **universe**. Debian: main. |

**Ubuntu**

- Enable **universe** (needed for cross-compiler and libc6-arm64-cross):
  ```bash
  sudo add-apt-repository universe
  sudo apt update
  ```
- Install cross-compiler (pulls in libc6-arm64-cross etc. if available):
  ```bash
  sudo apt install gcc-aarch64-linux-gnu
  ```
  If that fails on dependencies, try installing the libc cross package first, then gcc:
  ```bash
  sudo apt install libc6-arm64-cross libc6-dev-arm64-cross
  sudo apt install gcc-14-aarch64-linux-gnu   # or gcc-13-aarch64-linux-gnu
  ```
  The binary may be `aarch64-linux-gnu-gcc-14` (no meta `aarch64-linux-gnu-gcc`). The Makefile detects `aarch64-linux-gnu-gcc-14` and `aarch64-linux-gnu-gcc-13` and sets the linker accordingly.

**Debian**

- Cross-compiler and cross libc are in the standard repos:
  ```bash
  sudo apt update
  sudo apt install gcc-aarch64-linux-gnu libc6-dev-arm64-cross
  ```
  (Adjust if your Debian version uses a different gcc version package, e.g. `gcc-13-aarch64-linux-gnu`.)

**If `libc6-arm64-cross` is “not installable”**

- Typical causes: wrong or missing repo (e.g. universe not enabled), or mixed/held packages. Fix by enabling the right repo, then `sudo apt update` and retry. On some Ubuntu variants, the cross libc packages might be in a different component (e.g. ports); check your distro’s cross-compilation docs.

---

## 2. Aarch64 CUDA libs (for linking on x86 host)

**Base CUDA runtime (libcuda, libcudart, libcublas) for aarch64:**

- **No** standard Ubuntu/Debian package installs these **on an x86_64 host**.  
- You can **fetch them automatically** with the project script (recommended):

  ```bash
  cd rust
  make fetch-aarch64-cuda-libs
  ```

  This downloads NVIDIA’s arm64 .deb packages (cudart, nvrtc, cublas) and extracts them into `rust/cuda-arm64-libs/`. **libcuda.so** is not in the toolkit; it comes from the NVIDIA driver. To fetch it too (~300MB driver runfile):

  ```bash
  FETCH_DRIVER=1 make fetch-aarch64-cuda-libs
  ```

  Then build:

  ```bash
  make arm64
  ```

  (Override lib dir if needed: `AARCH64_CUDA_LIB_DIR=/path make arm64`.)

- **Manual options** (if you prefer not to use the script):

**Option A: Download CUDA Toolkit for Linux ARM64 and extract libs**

1. Go to [NVIDIA CUDA Toolkit downloads](https://developer.nvidia.com/cuda-downloads).
2. Choose: Linux → ARM64 (e.g. aarch64-sbsa or your target) → your distro/version.
3. Download the **runfile** or the **arm64 .deb** (e.g. `cuda-toolkit-12-x_12.x.x_arm64.deb` or the full toolkit).
4. On an x86 host, **extract** the .deb(s) (do not install):
   ```bash
   mkdir -p /opt/cuda-arm64
   dpkg -x cuda-toolkit-12-x_12.x.x_arm64.deb /opt/cuda-arm64
   # If there are multiple .deb packages, extract each into the same prefix.
   ```
5. Use the path that contains `libcuda.so` (and libcudart, libcublas) as `AARCH64_CUDA_LIB_DIR`, e.g.:
   ```bash
   export AARCH64_CUDA_LIB_DIR=/opt/cuda-arm64/usr/local/cuda/lib64
   make arm64
   ```
   (Exact path depends on how the .deb is laid out; adjust after extraction.)

**Option B: Copy from an ARM64 machine with CUDA**

- On a Jetson or other ARM64 system with CUDA installed, copy from `/usr/local/cuda/lib64` or `/usr/lib/aarch64-linux-gnu` (e.g. `libcuda.so*`, `libcudart.so*`, `libcublas.so*`) to a directory on the x86 build host and set `AARCH64_CUDA_LIB_DIR` to that directory when running `make arm64`.

**Option C: NVIDIA cross repo (cuDNN only)**

- For **cuDNN** only (not needed for tor-v3-vanity):
  ```bash
  # Add keyring (see NVIDIA CUDA install guide for exact key/url)
  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/cross-linux-aarch64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt update
  sudo apt install cudnn9-cross-aarch64   # optional; not sufficient for tor-v3-vanity link
  ```

---

## 3. Summary

| Requirement | Exists in Ubuntu/Debian? | How to install / get it |
|-------------|---------------------------|---------------------------|
| aarch64 gcc | Yes (universe on Ubuntu) | `sudo add-apt-repository universe && sudo apt update && sudo apt install gcc-aarch64-linux-gnu` (or install `libc6-arm64-cross` then `gcc-14-aarch64-linux-gnu`) |
| aarch64 libc (cross) | Yes (universe on Ubuntu) | Usually pulled in by gcc-aarch64; or `sudo apt install libc6-arm64-cross libc6-dev-arm64-cross` |
| aarch64 CUDA libs (libcuda, cudart, cublas) | No apt package on x86 | **Recommended:** `make fetch-aarch64-cuda-libs` (optionally `FETCH_DRIVER=1` for libcuda). Or extract ARM64 toolkit .deb(s) or copy from an ARM64 machine; set `AARCH64_CUDA_LIB_DIR`. |

**Minimal steps for cross-arm64 on Ubuntu (recommended):**

```bash
cd rust
make fetch-aarch64-cuda-libs     # fetches cudart, cublas; optionally FETCH_DRIVER=1 for libcuda
make arm64
```

**Minimal steps (manual libs):** Get aarch64 CUDA libs via Option A or B above, then:

```bash
cd rust
./scripts/setup-cross-arm64.sh
make arm64
# Or: AARCH64_CUDA_LIB_DIR=/path/to/libs make arm64
```

