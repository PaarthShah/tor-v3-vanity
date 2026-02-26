#!/usr/bin/env bash
# Fetch x86_64 (amd64) CUDA runtime libs for cross-compiling from arm64 to amd64.
# Run from rust/; creates cuda-x86-64-libs/ by default.
#
# Usage:
#   ./scripts/fetch-x86-64-cuda-libs.sh [OUTPUT_DIR]
#   FETCH_DRIVER=1 ./scripts/fetch-x86-64-cuda-libs.sh   # also download driver for libcuda.so
#
# Then: make amd64
# (X86_64_CUDA_LIB_DIR defaults to cuda-x86-64-libs when cross-compiling from arm64)

set -e

RUST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-${RUST_DIR}/cuda-x86-64-libs}"
BASE_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64"

# CUDA 12.6 runtime .debs (cudart, nvrtc, cublas) for amd64
DEBS=(
  "cuda-cudart-12-6_12.6.37-1_amd64.deb"
  "cuda-nvrtc-12-6_12.6.20-1_amd64.deb"
  "libcublas-12-6_12.6.0.22-1_amd64.deb"
)

# Optional: NVIDIA Linux x86_64 driver runfile to get libcuda.so (~300MB)
DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-570.153.02}"
DRIVER_RUN="NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"
DRIVER_URL="https://download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/${DRIVER_RUN}"

echo "Output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for deb in "${DEBS[@]}"; do
  url="${BASE_URL}/${deb}"
  echo "Fetching $deb ..."
  curl -sL -o "$TMP/$deb" "$url"
  (cd "$TMP" && dpkg-deb -x "$deb" "extract_$deb")
  find "$TMP/extract_$deb" \( -type f -o -type l \) \( -name '*.so' -o -name '*.so.*' \) -exec cp -a {} "$OUTPUT_DIR/" \;
done

# libcuda.so: from the NVIDIA driver
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
  EXTRACTED="$TMP/NVIDIA-Linux-x86_64-${DRIVER_VERSION}"
  [ ! -d "$EXTRACTED" ] && EXTRACTED="$TMP"
  while IFS= read -r -d '' f; do
    cp -a "$f" "$OUTPUT_DIR/"
  done < <(find "$EXTRACTED" -type f -name 'libcuda.so*' -print0 2>/dev/null)
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
    echo "Could not find libcuda.so in extracted driver."
  else
    echo "libcuda.so installed from driver."
  fi
else
  echo ""
  echo "libcuda.so is not in the CUDA toolkit debs; it comes from the NVIDIA driver."
  echo "Either:"
  echo "  1) Run with: FETCH_DRIVER=1 $0 $*"
  echo "  2) Copy libcuda.so / libcuda.so.1 from an x86_64 machine with NVIDIA driver"
  echo "     into $OUTPUT_DIR"
  echo ""
fi

# Ensure libcudart.so and libcublas.so symlinks
for f in "$OUTPUT_DIR"/libcudart.so*; do
  [ -e "$f" ] || continue
  base="$(basename "$f")"
  case "$base" in
    libcudart.so) ;;
    libcudart.so.12*) [ ! -f "$OUTPUT_DIR/libcudart.so" ] && ln -sf "$base" "$OUTPUT_DIR/libcudart.so" ;;
    *) ;;
  esac
done
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
echo "x86_64 CUDA libs are in: $OUTPUT_DIR"
if [ ! -f "$OUTPUT_DIR/libcuda.so" ] && [ ! -f "$OUTPUT_DIR/libcuda.so.1" ]; then
  echo "Add libcuda.so (see above) then run:"
else
  echo "Run:"
fi
echo "  make amd64"
echo ""
