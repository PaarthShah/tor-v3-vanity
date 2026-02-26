BINARY := t3v
# Output dir for binary (override for packaging: make DEB_DIR=/path x86_64)
DEB_DIR ?= $(CURDIR)/../deb/amd64

.PHONY: all setup x86_64 clean
all: x86_64

# Install nightly + NVPTX target + components if absent (idempotent). Required for PTX kernel build.
setup:
	@echo "Ensuring nightly toolchain and PTX build deps..."
	rustup install nightly && \
	rustup target add nvptx64-nvidia-cuda --toolchain nightly && \
	rustup component add llvm-bitcode-linker llvm-tools rust-src --toolchain nightly

x86_64: setup
	# build into a temp area
	CARGO_TARGET_DIR=target/x86_64 \
	  cargo +nightly build --release --target x86_64-unknown-linux-gnu
	mkdir -p $(DEB_DIR)
	# move only the binary into the deb folder
	mv target/x86_64/x86_64-unknown-linux-gnu/release/$(BINARY) $(DEB_DIR)/$(BINARY)

clean:
	rm -rf target $(DEB_DIR)/$(BINARY)
