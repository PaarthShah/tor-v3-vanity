# Building for amd64 (x86_64)

## Native on amd64

On an x86_64 host with CUDA installed:

```bash
cd rust
make amd64
```

Binary: `deb/amd64/t3v`. Use `CUDA_LIB_DIR` or `CUDA_HOME` if CUDA is not in `/usr/local/cuda` or `/usr/lib/x86_64-linux-gnu`.

## Cross-compile from arm64 to amd64

On an aarch64 host (e.g. Jetson, ARM server), **`make amd64`** cross-compiles automatically. You need:

1. **x86_64 cross-compiler** — The Makefile runs `scripts/setup-cross-x86-64.sh` when you run `make amd64` on arm64; that script installs the cross-compiler (e.g. `gcc-x86-64-linux-gnu`) if missing.

2. **x86_64 CUDA libs** for linking. Easiest: run `make fetch-x86-64-cuda-libs` (optionally `FETCH_DRIVER=1` to include libcuda), then run `make amd64`. The Makefile defaults `X86_64_CUDA_LIB_DIR` to `rust/cuda-x86-64-libs`. Otherwise copy `libcuda.so*`, `libcudart.so*`, `libcublas.so*` from an x86_64 machine with CUDA into a directory and set `X86_64_CUDA_LIB_DIR=/path/to/dir`.

3. **Build:**

   ```bash
   make amd64
   ```

   Or with a custom lib dir: `X86_64_CUDA_LIB_DIR=/path/to/libs make amd64`.

The binary is written to `deb/amd64/t3v` and runs on x86_64 Linux with an NVIDIA GPU and driver.
