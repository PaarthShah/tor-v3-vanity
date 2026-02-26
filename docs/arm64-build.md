# Building for ARM64 (aarch64)

## Is it possible?

**Yes.** The host binary can be built for `aarch64-unknown-linux-gnu`. The PTX kernel is unchanged (same `nvptx64-nvidia-cuda` GPU code); only the host that loads it changes.

## Requirements

- **Rust:** nightly with `aarch64-unknown-linux-gnu` target and the same NVPTX setup (rust-src, llvm-bitcode-linker, llvm-tools, nvptx64-nvidia-cuda).
- **CUDA on ARM64:** NVIDIA supports CUDA on ARM64 Linux (Jetson, ARM servers with SBSA). You need the [CUDA Toolkit for your ARM64 platform](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=arm64-sbsa) or Jetson SDK. Libraries are typically under `/usr/local/cuda/lib64` or `/usr/lib/aarch64-linux-gnu`.
- **rustacuda:** The crate’s docs list x86 as “supported”; they do not explicitly forbid aarch64. It’s a thin wrapper around the CUDA Driver API. On a machine with ARM64 + CUDA libs, building and linking for aarch64 should work. If you hit compile/link errors specific to aarch64, they would be in rustacuda or the cuda-sys layer.

## How to build

### Native on ARM64 (e.g. Jetson, ARM server)

On the ARM64 machine with CUDA installed:

```bash
cd rust
rustup target add aarch64-unknown-linux-gnu --toolchain nightly
make arm64
```

Or without the Makefile:

```bash
cargo +nightly build --release --target aarch64-unknown-linux-gnu
```

Use `CUDA_LIB_DIR` or `CUDA_HOME` if CUDA is not in `/usr/local/cuda` or `/usr/lib/aarch64-linux-gnu`.

### Cross-compile from amd64 (x86_64) to ARM64

From an amd64 host, **`make arm64`** cross-compiles automatically (no separate target). You need:

1. **Cross-compiler:** `aarch64-linux-gnu-gcc`  
   - The Makefile runs `scripts/setup-cross-arm64.sh` when you run `make arm64` on amd64; that script installs the cross-compiler (e.g. `gcc-aarch64-linux-gnu`) if missing.

2. **Aarch64 CUDA libs** for linking. Easiest: run `make fetch-aarch64-cuda-libs` (optionally `FETCH_DRIVER=1` to include libcuda), then run `make arm64`. The Makefile defaults `AARCH64_CUDA_LIB_DIR` to `rust/cuda-arm64-libs`. Otherwise:

   - **From an ARM64 machine:** Copy `libcuda.so*`, `libcudart.so*`, `libcublas.so*` (and any deps they need) from `/usr/local/cuda/lib64` or `/usr/lib/aarch64-linux-gnu` into a dir on the x86 host (e.g. `$HOME/cuda-arm64-libs`).
   - **NVIDIA ARM64 CUDA toolkit:** Download the [CUDA Toolkit for Linux ARM64](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=arm64-sbsa) (runfile or package). Extract or install into a prefix (e.g. `/opt/cuda-arm64`) and use `AARCH64_CUDA_LIB_DIR=/opt/cuda-arm64/lib64`.
   - **Ubuntu cross repo (if available for your distro):** NVIDIA sometimes provides `cross-linux-aarch64` packages; you can install the aarch64 library packages and point `AARCH64_CUDA_LIB_DIR` at the installed aarch64 lib path.

3. **Build:** From `rust/`:

   ```bash
   make arm64
   ```

   If you used a custom lib dir: `AARCH64_CUDA_LIB_DIR=/path/to/libs make arm64`.

   The binary is written to `deb/arm64/t3v`.

## Summary

| Scenario                         | Supported |
|----------------------------------|-----------|
| Native build on ARM64 + CUDA     | Yes (`make arm64`) |
| Cross-compile amd64 → arm64   | Yes (`make arm64` on amd64 host) |
| PTX kernel                      | Same as x86 (nvptx64-nvidia-cuda) |
