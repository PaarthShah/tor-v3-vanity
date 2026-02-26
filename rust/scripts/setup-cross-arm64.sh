#!/usr/bin/env bash
# Setup dependencies for cross-compiling from x86_64 to aarch64 (Ubuntu/Debian).
# Invoked by: make setup-cross-arm64-deps
# Can also be run standalone: ./scripts/setup-cross-arm64.sh
set -e

find_aarch64_gcc() {
	command -v aarch64-linux-gnu-gcc 2>/dev/null || \
	command -v aarch64-linux-gnu-gcc-14 2>/dev/null || \
	command -v aarch64-linux-gnu-gcc-13 2>/dev/null || \
	command -v aarch64-linux-gnu-gcc-12 2>/dev/null || true
}

if [ -n "$(find_aarch64_gcc)" ]; then
	echo "aarch64 cross-compiler already available: $(find_aarch64_gcc)"
	exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
	echo "This script supports only Debian/Ubuntu (apt-get)."
	echo "Install aarch64 gcc manually and ensure aarch64-linux-gnu-gcc (or -14/-13) is in PATH."
	exit 1
fi

# Ubuntu: ensure main + universe are available (libc6-arm64-cross is in main, gcc-aarch64 in universe)
if [ -f /etc/os-release ]; then
	. /etc/os-release
	if [ "${ID:-}" = "ubuntu" ]; then
		# Ubuntu 24.04+: ubuntu.sources may have the main archive disabled (Enabled: no). Enable it so we get main + universe.
		UB_SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
		if [ -f "$UB_SOURCES" ] && grep -q "Enabled: no" "$UB_SOURCES" 2>/dev/null; then
			echo "Enabling Ubuntu archive (main/universe) in $UB_SOURCES..."
			sudo sed -i '/^URIs:.*archive\.ubuntu\.com/,/^Enabled:/ s/^Enabled: no$/Enabled: yes/' "$UB_SOURCES"
		fi
		# Ensure universe is in Components (add-apt-repository universe if needed)
		if ! grep -q "universe" "$UB_SOURCES" 2>/dev/null; then
			echo "Enabling Ubuntu universe repository..."
			sudo add-apt-repository -y universe
		fi
		sudo apt-get update -qq
	fi
fi

# Debian: ensure we have latest index
if [ -f /etc/debian_version ] && [ "${ID:-}" != "ubuntu" ]; then
	sudo apt-get update -qq
fi

# 1) Prefer crossbuild-essential-arm64 (metapackage: gcc + libc cross in one go)
# 2) Else gcc-aarch64-linux-gnu (meta)
# 3) Else libc6-arm64-cross + libc6-dev-arm64-cross then gcc-14/13-aarch64-linux-gnu
echo "Installing aarch64 cross-compiler..."
if sudo apt-get install -y crossbuild-essential-arm64 2>/dev/null; then
	:
elif sudo apt-get install -y gcc-aarch64-linux-gnu 2>/dev/null; then
	:
elif sudo apt-get install -y libc6-arm64-cross libc6-dev-arm64-cross 2>/dev/null; then
	if ! sudo apt-get install -y gcc-14-aarch64-linux-gnu 2>/dev/null; then
		sudo apt-get install -y gcc-13-aarch64-linux-gnu 2>/dev/null || true
	fi
else
	echo ""
	echo "Could not install aarch64 cross-compiler."
	echo "Ensure Ubuntu main+universe or Debian main are enabled and run: sudo apt update"
	echo "Then try one of:"
	echo "  sudo apt install crossbuild-essential-arm64"
	echo "  sudo apt install gcc-aarch64-linux-gnu"
	echo "  sudo apt install libc6-arm64-cross libc6-dev-arm64-cross gcc-14-aarch64-linux-gnu"
	echo "See docs/cross-arm64-deps-ubuntu-debian.md"
	echo ""
	exit 1
fi

GCC="$(find_aarch64_gcc)"
if [ -z "$GCC" ]; then
	echo ""
	echo "aarch64 gcc still not found in PATH after install."
	echo "Install one of: gcc-aarch64-linux-gnu, gcc-14-aarch64-linux-gnu, gcc-13-aarch64-linux-gnu"
	echo "See docs/cross-arm64-deps-ubuntu-debian.md"
	echo ""
	exit 1
fi

echo "aarch64 cross-compiler ready: $GCC"
