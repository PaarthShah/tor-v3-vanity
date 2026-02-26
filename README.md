# tor-v3-vanity
A TOR v3 vanity url generator designed to run on an NVIDIA GPU.

Disclaimer: This project is brand new and hasn't been thoroughly vetted.
Please report any bugs you find [here](https://github.com/dr-bonez/tor-v3-vanity/issues).

The program is designed to use all available CUDA devices, and will automatically decide the number of threads and blocks to use.

Now supports multiple prefixes!

## Compatibility

- **Rust:** 2021 edition; stable or nightly (nightly required for CUDA build).
- **CLI:** [clap](https://clap.rs) 4 with derive API.
- **Errors:** [anyhow](https://github.com/dtolnay/anyhow) for application error handling.
- **GPU target:** `nvptx64-nvidia-cuda`; kernel built with Rust’s **llvm-bitcode-linker** (no ptx-linker).

## Installation

- [Install Rust](https://rustup.rs) (rustup)
- **CUDA** — required to build and run. See [CUDA install](https://developer.nvidia.com/cuda-downloads).

### Why CUDA might be “missing” on the build machine

- **Only the NVIDIA driver is installed** — the driver gives you `libcuda.so` at runtime, but on some distros the **CUDA toolkit** (libraries and headers for building) is a separate install. You need the toolkit (or at least the libs) to *build*.
- **CUDA is in a non-default path** — e.g. installed under `/opt`, or from a package that puts libs in `/usr/lib/x86_64-linux-gnu`. Use `CUDA_LIB_DIR` or `CUDA_HOME` (see Troubleshooting).
- **Different machine** — building on a machine without CUDA (e.g. CI or a laptop) will fail at link; build on a machine with CUDA, or install the CUDA toolkit there.

### How to check CUDA is present

- **Libraries (needed to build):**  
  `ls /usr/local/cuda/lib64/libcuda.so` or `ls /usr/lib/x86_64-linux-gnu/libcuda.so`  
  At least one should exist (or set `CUDA_LIB_DIR` to the directory that contains `libcuda.so`).
- **Optional (for sanity):**  
  `nvidia-smi` (driver/runtime) and/or `nvcc --version` (toolkit compiler).

### How to install CUDA (if missing)

- **Linux:** [NVIDIA CUDA download](https://developer.nvidia.com/cuda-downloads) — choose your distro and install the toolkit (or the “runfile” and select the libraries/development components).
- **Ubuntu/Debian:** You can install the meta-package and libs, e.g.  
  `sudo apt install nvidia-cuda-toolkit`  
  (libs often end up in `/usr/lib/x86_64-linux-gnu`; the build will look there as a fallback.)

**One-time setup (reproducible on any machine).** Either:

- **Makefile (recommended):** from `rust/`, run `make` — it runs setup then build. Or run `make setup` once, then `cargo +nightly build --release`.
- **Manual:** run once:
  ```bash
  rustup install nightly && rustup target add nvptx64-nvidia-cuda --toolchain nightly && rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly
  ```
  Then build: `cargo +nightly build --release` (from `rust/`).

Or install the binary: `cargo +nightly install --path .` (from `rust/`).

**ARM64 (aarch64):** `make arm64`. On an ARM64 host this builds natively; on an amd64 host it cross-compiles (run `make fetch-aarch64-cuda-libs` first, optionally `FETCH_DRIVER=1` for libcuda). See [docs/arm64-build.md](docs/arm64-build.md).

## Troubleshooting

- **`Cargo.lock does not exist` / `unable to build with the standard library` / `rust-src`**
  - The build needs the nightly standard library source. Run the one-time setup from the Installation section (single line with `rustup install nightly && ... rust-src ...`), then `cargo +nightly build --release`.

- **Build appears stuck at `tor-v3-vanity(build)`**
  - The build script compiles the NVPTX kernel as a separate step.
  - First build can take several minutes while toolchain artifacts are compiled.
  - Run with `cargo +nightly build --release -vv` to see detailed progress.

- **`linker rust-ptx-linker not found`**
  - Do **not** install legacy `ptx-linker`.
  - Run the one-time setup (Installation section), then `cargo +nightly build --release`.

- **Nightly-only NVPTX errors**
  - Run the one-time setup. Check active compiler: `rustc +nightly -V`.

- **`unable to find library -lcuda` / `-lcudart` / `-lcublas`**
  - CUDA libraries are missing or not on the default path. See **Why CUDA might be “missing”** and **How to check / install CUDA** above.
  - If CUDA is installed but in a different directory, set `CUDA_LIB_DIR` (path to the dir containing `libcuda.so`) or `CUDA_HOME` (CUDA root; build uses `$CUDA_HOME/lib64`). Example: `make CUDA_LIB_DIR=/usr/lib/x86_64-linux-gnu`

## Usage

- Create output dir
  - `mkdir mykeys`
- Run `t3v`
  - `t3v --dst mykeys/ myprefix1,myprefix2`
- Use the resulting file as your `hs_ed25519_secret_key`
  - `cat mykeys/myprefixwhatever.onion > /var/lib/tor/hidden_service/hs_ed25519_secret_key`

## Bench
On my 1070ti, I get the following time estimates:

| Prefix Length | Time       |
| ------------- | ---------- |
|             5 | 7 minutes  |
|             6 | 3.5 hours  |
|             7 | 5 days     |
|             8 | 22.5 weeks |
|             9 | 14 years   |
