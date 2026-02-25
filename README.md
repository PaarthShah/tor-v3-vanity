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

- [Install Rust](https://rustup.rs)
- [Install CUDA](https://developer.nvidia.com/cuda-downloads)
- Nightly and NVPTX target:
  - `rustup install nightly`
  - `rustup target add nvptx64-nvidia-cuda --toolchain nightly`
- Nightly components (for building the GPU kernel; **no ptx-linker needed**):
  - `rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly`
- Build:
  - `git clone https://github.com/dr-bonez/tor-v3-vanity`
  - `cd tor-v3-vanity`
  - `cargo +nightly build --release`
- Or install the binary: `cargo +nightly install --path .`

## Troubleshooting

- **Build appears stuck at `tor-v3-vanity(build)`**
  - The build script compiles the NVPTX kernel as a separate step.
  - First build can take several minutes while toolchain artifacts are compiled.
  - Run with `cargo +nightly build --release -vv` to see detailed progress.

- **`linker rust-ptx-linker not found`**
  - Do **not** install legacy `ptx-linker`.
  - Ensure nightly components are installed:
    - `rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly`
  - Re-run with nightly: `cargo +nightly build --release`.

- **Nightly-only NVPTX errors**
  - Confirm you are using nightly and the NVPTX target is installed:
    - `rustup target add nvptx64-nvidia-cuda --toolchain nightly`
  - Check active compiler:
    - `rustc +nightly -V`

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
