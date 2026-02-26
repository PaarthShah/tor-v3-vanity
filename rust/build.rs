//! Build the PTX kernel using the official llvm-bitcode-linker (no ptx-linker).
//!
//! Requires nightly and: rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rustc-link-search=native=/usr/local/cuda/lib64/");
    println!("cargo:rerun-if-changed=core");
    println!("cargo:rerun-if-env-changed=KERNEL_PTX_PATH");

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let target_dir = env::var("CARGO_TARGET_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| manifest_dir.join("target"));
    // Use a separate target dir for the kernel build to avoid deadlock: the outer
    // cargo holds the main target lock; inner cargo would wait forever for it.
    let kernel_target_dir = target_dir.join("nvptx-kernel");
    let nvptx_dir = kernel_target_dir
        .join("nvptx64-nvidia-cuda")
        .join("release");

    eprintln!("Building PTX kernel for nvptx64-nvidia-cuda (first time can take several minutes)...");

    let status = Command::new(env::var("CARGO").unwrap_or_else(|_| "cargo".into()))
        .args([
            "rustc",
            "-p",
            "tor-v3-vanity-core",
            "--target",
            "nvptx64-nvidia-cuda",
            "-Z",
            "build-std=core,panic_abort",
            "--release",
            "--",
            "-Z",
            "unstable-options",
            "-C",
            "link-self-contained=+linker",
            "-C",
            "linker-flavor=llbc",
            "-C",
            "target-cpu=sm_75",
        ])
        .env("CARGO_TARGET_DIR", &kernel_target_dir)
        .current_dir(&manifest_dir)
        .status();

    let status = match status {
        Ok(s) => s,
        Err(e) => {
            eprintln!(
                "cargo:warning=Failed to run cargo for kernel build: {}. \
                 Build with: cargo +nightly build --release",
                e
            );
            panic!("kernel build failed: {}", e);
        }
    };

    if !status.success() {
        eprintln!(
            "cargo:warning=Kernel build failed. Ensure you have nightly and: \
             rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly"
        );
        panic!("kernel build failed");
    }

    // Find the generated .ptx (llbc produces PTX for cdylib)
    let deps = nvptx_dir.join("deps");
    let pattern = deps.join("*.ptx");
    let pattern = pattern.to_str().expect("path is valid UTF-8");
    let ptx_path = glob::glob(pattern)
        .ok()
        .and_then(|mut g| g.next())
        .and_then(|e| e.ok());

    let ptx_path = match ptx_path {
        Some(p) => p,
        None => {
            eprintln!("cargo:warning=No .ptx found under {}", deps.display());
            panic!("kernel build did not produce a .ptx file under {}", deps.display());
        }
    };

    let ptx_path = ptx_path.canonicalize().unwrap_or(ptx_path);
    println!("cargo:rustc-env=KERNEL_PTX_PATH={}", ptx_path.display());
}
