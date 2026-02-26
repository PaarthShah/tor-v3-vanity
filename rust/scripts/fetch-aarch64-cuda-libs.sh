#!/usr/bin/env bash
# Fetch aarch64 CUDA runtime libs (libcudart, libcublas, libcuda) for cross-compiling
# from x86 to arm64. Run from repo root or rust/; creates cuda-arm64-libs/ by default.
#
# Usage:
#   ./scripts/fetch-aarch64-cuda-libs.sh [OUTPUT_DIR]
#   FETCH_DRIVER=1 ./scripts/fetch-aarch64-cuda-libs.sh   # also download driver for libcuda.so
#
# Then: make arm64
# (AARCH64_CUDA_LIB_DIR defaults to cuda-arm64-libs when cross-compiling from amd64)

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${RUST_DIR}/cuda-arm64-libs}"
BASE_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/arm64"

# CUDA 12.6 runtime .debs (cudart, nvrtc, cublas) for arm64
DEBS=(
  "cuda-cudart-12-6_12.6.37-1_arm64.deb"
  "cuda-nvrtc-12-6_12.6.20-1_arm64.deb"
  "libcublas-12-6_12.6.0.22-1_arm64.deb"
)

# Optional: NVIDIA Linux aarch64 driver runfile to get libcuda.so (~300MB)
# If FETCH_DRIVER=1 we download and extract it.
DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-570.153.02}"
DRIVER_RUN="NVIDIA-Linux-aarch64-${DRIVER_VERSION}.run"
DRIVER_URL="https://download.nvidia.com/XFree86/Linux-aarch64/${DRIVER_VERSION}/${DRIVER_RUN}"

echo "Output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Download and extract .debs; copy all .so* into OUTPUT_DIR
for deb in "${DEBS[@]}"; do
  url="${BASE_URL}/${deb}"
  echo "Fetching $deb ..."
  curl -sL -o "$TMP/$deb" "$url"
  (cd "$TMP" && dpkg-deb -x "$deb" "extract_$deb")
  find "$TMP/extract_$deb" \( -type f -o -type l \) \( -name '*.so' -o -name '*.so.*' \) -exec cp -a {} "$OUTPUT_DIR/" \;
done

# libcuda.so: not in the toolkit debs; it comes from the NVIDIA driver.
if [ -f "$OUTPUT_DIR/libcuda.so" ] || [ -f "$OUTPUT_DIR/libcuda.so.1" ]; then
  echo "libcuda.so already present."
elif [ "${FETCH_DRIVER}" = "1" ]; then
  echo "Fetching NVIDIA driver runfile (large) for libcuda.so ..."
  curl -sL -o "$TMP/$DRIVER_RUN" "$DRIVER_URL"
  if [ ! -s "$TMP/$DRIVER_RUN" ]; then
    echo "Driver download failed or empty. Try setting NVIDIA_DRIVER_VERSION (e.g. 570.86.16)."
    exit 1
  fi
  chmod +x "$TMP/$DRIVER_RUN"
  (cd "$TMP" && sh "./$DRIVER_RUN" --extract-only)
  # Extracted dir is typically NVIDIA-Linux-aarch64-<version>
  EXTRACTED="$TMP/NVIDIA-Linux-aarch64-${DRIVER_VERSION}"
  [ ! -d "$EXTRACTED" ] && EXTRACTED="$TMP"
  while IFS= read -r -d '' f; do
    cp -a "$f" "$OUTPUT_DIR/"
  done < <(find "$EXTRACTED" -type f -name 'libcuda.so*' -print0 2>/dev/null)
  # Linker expects libcuda.so or libcuda.so.1; driver ships libcuda.so.VERSION
  for f in "$OUTPUT_DIR"/libcuda.so.*; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    if [ "$base" = "libcuda.so.1" ]; then
      [ ! -f "$OUTPUT_DIR/libcuda.so" ] && ln -sf libcuda.so.1 "$OUTPUT_DIR/libcuda.so"
      break
    fi
  done
  if [ ! -f "$OUTPUT_DIR/libcuda.so" ]; then
    for f in "$OUTPUT_DIR"/libcuda.so.*; do
      [ -e "$f" ] || continue
      ln -sf "$(basename "$f")" "$OUTPUT_DIR/libcuda.so"
      break
    done
  fi
  if [ ! -f "$OUTPUT_DIR/libcuda.so" ] && [ ! -f "$OUTPUT_DIR/libcuda.so.1" ]; then
    echo "Could not find libcuda.so in extracted driver. You may need to copy it from an arm64 machine."
  else
    echo "libcuda.so installed from driver."
  fi
else
  echo ""
  echo "libcuda.so is not in the CUDA toolkit debs; it comes from the NVIDIA driver."
  echo "Either:"
  echo "  1) Run with: FETCH_DRIVER=1 $0 $*"
  echo "     (downloads ~300MB driver runfile and extracts libcuda.so)"
  echo "  2) Copy libcuda.so / libcuda.so.1 from an arm64 machine with NVIDIA driver"
  echo "     into $OUTPUT_DIR"
  echo ""
fi

# Ensure linker can find libcudart.so (not only .so.12)
for f in "$OUTPUT_DIR"/libcudart.so*; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  case "$base" in
    libcudart.so) ;;
    libcudart.so.12*) [ ! -f "$OUTPUT_DIR/libcudart.so" ] && ln -sf "$base" "$OUTPUT_DIR/libcudart.so" ;;
    *) ;;
  esac
done
# Same for cublas
for f in "$OUTPUT_DIR"/libcublas.so*; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  case "$base" in
    libcublas.so) ;;
    libcublas.so.12*) [ ! -f "$OUTPUT_DIR/libcublas.so" ] && ln -sf "$base" "$OUTPUT_DIR/libcublas.so" ;;
    *) ;;
  esac
done

echo ""
echo "Aarch64 CUDA libs are in: $OUTPUT_DIR"
if [ ! -f "$OUTPUT_DIR/libcuda.so" ] && [ ! -f "$OUTPUT_DIR/libcuda.so.1" ]; then
  echo "Add libcuda.so (see above) then run:"
else
  echo "Run:"
fi
echo "  make arm64"
echo ""
