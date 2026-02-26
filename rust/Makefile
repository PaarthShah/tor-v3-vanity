BINARY := t3v

.PHONY: all x86_64 clean
all: x86_64

x86_64:
	# build into a temp area
	CARGO_TARGET_DIR=target/x86_64 \
	  cargo +nightly build --release --target x86_64-unknown-linux-gnu
	mkdir -p $(HOME)/dev/tor-v3-vanity/deb/amd64
	# move only the binary into the deb folder
	mv target/x86_64/x86_64-unknown-linux-gnu/release/$(BINARY) \
	   $(HOME)/dev/tor-v3-vanity/deb/amd64/$(BINARY)

clean:
	rm -rf target $(HOME)/dev/tor-v3-vanity/deb/amd64/$(BINARY)
