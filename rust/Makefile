BINARY := t3v
# Output dir for binary (override for packaging: make DEB_DIR=/path x86_64)
DEB_DIR ?= $(CURDIR)/../deb/amd64

# Where to look for CUDA libs (override if CUDA is elsewhere)
CUDA_LIB_DIR ?= /usr/local/cuda/lib64
CUDA_LIB_FALLBACK := /usr/lib/x86_64-linux-gnu

.PHONY: all setup check-cuda install-cuda x86_64 clean
all: x86_64

# Install CUDA toolkit via apt (Debian/Ubuntu only; requires sudo). Run once if check-cuda fails.
install-cuda:
	@if [ -f "/etc/debian_version" ] && command -v apt-get >/dev/null 2>&1; then \
		echo "Installing CUDA toolkit (nvidia-cuda-toolkit) via apt..."; \
		sudo apt-get update && sudo apt-get install -y nvidia-cuda-toolkit; \
		echo "Done. Run: make check-cuda"; \
	else \
		echo "install-cuda is only for Debian/Ubuntu (apt)."; \
		echo "On other distros install CUDA manually: https://developer.nvidia.com/cuda-downloads"; \
		exit 1; \
	fi

# Install nightly + NVPTX target + components if absent (idempotent). Required for PTX kernel build.
setup:
	@echo "Ensuring nightly toolchain and PTX build deps..."
	rustup install nightly && \
	rustup target add nvptx64-nvidia-cuda --toolchain nightly && \
	rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly

# Fail early with clear instructions if CUDA libs are not found.
check-cuda:
	@if [ -f "$(CUDA_LIB_DIR)/libcuda.so" ] || [ -f "$(CUDA_LIB_FALLBACK)/libcuda.so" ]; then \
		echo "CUDA libs found."; \
	else \
		echo ""; \
		echo "CUDA libraries not found. Build will fail at link."; \
		echo "  Checked: $(CUDA_LIB_DIR)/libcuda.so and $(CUDA_LIB_FALLBACK)/libcuda.so"; \
		echo ""; \
		echo "Install CUDA: make install-cuda  (Debian/Ubuntu; needs sudo)"; \
		echo "  Or: https://developer.nvidia.com/cuda-downloads"; \
		echo "  If CUDA is elsewhere: make CUDA_LIB_DIR=/path/to/dir"; \
		echo ""; \
		exit 1; \
	fi

x86_64: setup check-cuda
	# build into a temp area
	CARGO_TARGET_DIR=target/x86_64 \
	  cargo +nightly build --release --target x86_64-unknown-linux-gnu
	mkdir -p $(DEB_DIR)
	# move only the binary into the deb folder
	mv target/x86_64/x86_64-unknown-linux-gnu/release/$(BINARY) $(DEB_DIR)/$(BINARY)

clean:
	rm -rf target $(DEB_DIR)/$(BINARY)
