#!/usr/bin/env bash
# Setup dependencies for cross-compiling from aarch64 to x86_64 (Ubuntu/Debian).
# Invoked by: make amd64 when HOST_ARCH is aarch64
# Can also be run standalone: ./scripts/setup-cross-x86-64.sh
set -e

find_x86_64_gcc() {
	command -v x86_64-linux-gnu-gcc 2>/dev/null || \
	command -v x86_64-linux-gnu-gcc-14 2>/dev/null || \
	command -v x86_64-linux-gnu-gcc-13 2>/dev/null || \
	command -v x86_64-linux-gnu-gcc-12 2>/dev/null || true
}

if [ -n "$(find_x86_64_gcc)" ]; then
	echo "x86_64 cross-compiler already available: $(find_x86_64_gcc)"
	exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
	echo "This script supports only Debian/Ubuntu (apt-get)."
	echo "Install x86_64 gcc manually and ensure x86_64-linux-gnu-gcc (or -14/-13) is in PATH."
	exit 1
fi

if [ -f /etc/os-release ]; then
	. /etc/os-release
	if [ "${ID:-}" = "ubuntu" ]; then
		UB_SOURCES="/etc/apt/sources.list.d/ubuntu.sources"
		if [ -f "$UB_SOURCES" ] && grep -q "Enabled: no" "$UB_SOURCES" 2>/dev/null; then
			echo "Enabling Ubuntu archive in $UB_SOURCES..."
			sudo sed -i '/^URIs:.*archive\.ubuntu\.com/,/^Enabled:/ s/^Enabled: no$/Enabled: yes/' "$UB_SOURCES"
		fi
		if ! grep -q "universe" "$UB_SOURCES" 2>/dev/null; then
			echo "Enabling Ubuntu universe repository..."
			sudo add-apt-repository -y universe
		fi
		sudo apt-get update -qq
	fi
fi

if [ -f /etc/debian_version ] && [ "${ID:-}" != "ubuntu" ]; then
	sudo apt-get update -qq
fi

# crossbuild-essential-amd64 or gcc-x86-64-linux-gnu (meta) or versioned gcc
echo "Installing x86_64 cross-compiler..."
if sudo apt-get install -y crossbuild-essential-amd64 2>/dev/null; then
	:
elif sudo apt-get install -y gcc-x86-64-linux-gnu 2>/dev/null; then
	:
elif sudo apt-get install -y libc6-amd64-cross libc6-dev-amd64-cross 2>/dev/null; then
	if ! sudo apt-get install -y gcc-14-x86-64-linux-gnu 2>/dev/null; then
		sudo apt-get install -y gcc-13-x86-64-linux-gnu 2>/dev/null || true
	fi
else
	echo ""
	echo "Could not install x86_64 cross-compiler."
	echo "Try: sudo apt update && sudo apt install gcc-x86-64-linux-gnu"
	echo "Or: sudo apt install crossbuild-essential-amd64"
	echo "See docs/amd64-build.md"
	echo ""
	exit 1
fi

GCC="$(find_x86_64_gcc)"
if [ -z "$GCC" ]; then
	echo ""
	echo "x86_64 gcc still not found in PATH after install."
	echo "Install one of: gcc-x86-64-linux-gnu, gcc-14-x86-64-linux-gnu, gcc-13-x86-64-linux-gnu"
	echo ""
	exit 1
fi

echo "x86_64 cross-compiler ready: $GCC"
