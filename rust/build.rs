//! Build the PTX kernel using the official llvm-bitcode-linker (no ptx-linker).
//!
//! Requires nightly and: rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly

use std::env;
use std::path::PathBuf;
use std::process::Command;

/// One-time setup command to print when components are missing (reproducible on any machine).
const SETUP_CMD: &str = "rustup install nightly && rustup target add nvptx64-nvidia-cuda --toolchain nightly && rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly";

fn toolchain_from_cargo_path(cargo: &str) -> Option<String> {
    // CARGO is e.g. /home/user/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/bin/cargo
    let path = std::path::Path::new(cargo);
    path.parent() // bin/
        .and_then(|p| p.parent()) // nightly-x86_64-unknown-linux-gnu
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .filter(|s| s.contains("nightly"))
        .map(|s| s.to_string())
}

fn check_nightly_components(toolchain: &str) -> Result<(), String> {
    let components = Command::new("rustup")
        .args(["component", "list", "--toolchain", toolchain, "--installed"])
        .output()
        .map_err(|e| format!("rustup component list failed: {}", e))?;
    let out = String::from_utf8_lossy(&components.stdout);
    let required = ["rust-src", "llvm-bitcode-linker", "llvm-tools"];
    for name in required {
        if !out.lines().any(|l| l.contains(name) && l.contains("installed")) {
            return Err(format!("missing component: {}", name));
        }
    }
    Ok(())
}

fn check_nvptx_target(toolchain: &str) -> Result<(), String> {
    let targets = Command::new("rustup")
        .args(["target", "list", "--toolchain", toolchain, "--installed"])
        .output()
        .map_err(|e| format!("rustup target list failed: {}", e))?;
    let out = String::from_utf8_lossy(&targets.stdout);
    if !out.contains("nvptx64-nvidia-cuda") {
        return Err("missing target: nvptx64-nvidia-cuda".to_string());
    }
    Ok(())
}

fn ensure_nightly_setup() {
    let cargo = env::var("CARGO").unwrap_or_else(|_| "cargo".into());
    let toolchain = toolchain_from_cargo_path(&cargo);
    let Some(ref tc) = toolchain else {
        // Not using rustup or path not recognizable; skip pre-check, kernel build will fail with its own error
        return;
    };
    if let Err(e) = check_nightly_components(tc) {
        eprintln!(
            "\n\ntor-v3-vanity build requires nightly with extra components.\n\
             Error: {}.\n\n\
             Run this once (reproducible on any machine):\n\n  {}\n\n\
             Then build with: cargo +nightly build --release\n",
            e, SETUP_CMD
        );
        panic!("missing nightly components: {}", e);
    }
    if let Err(e) = check_nvptx_target(tc) {
        eprintln!(
            "\n\ntor-v3-vanity build requires the NVPTX target for nightly.\n\
             Error: {}.\n\n\
             Run this once (reproducible on any machine):\n\n  {}\n\n\
             Then build with: cargo +nightly build --release\n",
            e, SETUP_CMD
        );
        panic!("missing nvptx target: {}", e);
    }
}

fn main() {
    println!("cargo:rustc-link-search=native=/usr/local/cuda/lib64/");
    println!("cargo:rerun-if-changed=core");
    println!("cargo:rerun-if-env-changed=KERNEL_PTX_PATH");

    ensure_nightly_setup();

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
                "\n\nFailed to run kernel build: {}.\n\nRun this once: {}\n\nThen: cargo +nightly build --release\n",
                e, SETUP_CMD
            );
            panic!("kernel build failed: {}", e);
        }
    };

    if !status.success() {
        eprintln!(
            "\n\nKernel build failed. Run this once (reproducible on any machine):\n\n  {}\n\nThen: cargo +nightly build --release\n",
            SETUP_CMD
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
