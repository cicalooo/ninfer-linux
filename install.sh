#!/usr/bin/env bash
# Install a prebuilt ninfer-all Linux CLI from GitHub Releases.
# Detects the GPU compute capability and fetches the matching archive.
set -euo pipefail

REPO="${NINFER_LINUX_REPO:-cicalooo/ninfer-linux}"
PREFIX="${NINFER_PREFIX:-/opt/ninfer}"
TAG="${NINFER_LINUX_TAG:-latest}"

usage() {
  cat <<EOF
usage: install.sh [--prefix DIR] [--tag TAG]

Install ninfer, ninfer-serve, ninfer-calibrate, and ninfer-perplexity.

  --prefix DIR   install root (default: /opt/ninfer)
  --tag TAG      GitHub release tag (default: latest)

Environment: NINFER_PREFIX, NINFER_LINUX_TAG, NINFER_LINUX_REPO
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

need() {
  command -v "$1" >/dev/null || {
    printf 'install.sh: missing %s\n' "$1" >&2
    exit 1
  }
}

need curl
need tar
need sha256sum

if ! command -v nvidia-smi >/dev/null; then
  printf 'install.sh: nvidia-smi not found. Install an NVIDIA driver (CUDA 13 / 580+).\n' >&2
  exit 1
fi

cap="$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n1 | tr -d '[:space:]')"
gpu="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || true)"
printf 'GPU: %s (compute %s)\n' "${gpu:-unknown}" "${cap:-unknown}"

case "$cap" in
  8.6|8.9) asset="ninfer-linux-x64-sm86.tar.gz" ;;
  12.0)
    printf 'install.sh: RTX 50-series / Blackwell needs an sm_120a build.\n' >&2
    printf 'This project only publishes sm_86 (RTX 30/40). Use:\n' >&2
    printf '  https://github.com/iamwavecut/ninfer-all\n' >&2
    printf '  docker pull ghcr.io/iamwavecut/ninfer-all\n' >&2
    exit 1
    ;;
  *)
    printf 'install.sh: no published binary for compute capability %s.\n' "${cap:-unknown}" >&2
    printf 'Published: sm_86 (NVIDIA compute 8.6 and 8.9 — RTX 30 and RTX 40).\n' >&2
    printf 'Build from https://github.com/iamwavecut/ninfer-all or use their Docker image.\n' >&2
    exit 1
    ;;
esac

if [[ "$TAG" == latest ]]; then
  base="https://github.com/${REPO}/releases/latest/download"
else
  base="https://github.com/${REPO}/releases/download/${TAG}"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf 'Downloading %s\n' "$asset"
curl -fL --retry 3 -o "$tmp/$asset" "$base/$asset"
curl -fL --retry 3 -o "$tmp/SHA256SUMS.txt" "$base/SHA256SUMS.txt"
(
  cd "$tmp"
  grep -F " $asset" SHA256SUMS.txt | sha256sum --check --strict
)

install_root="$PREFIX"
if [[ ! -w "$(dirname "$install_root")" ]] || { [[ -e "$install_root" ]] && [[ ! -w "$install_root" ]]; }; then
  if [[ "$(id -u)" -ne 0 ]]; then
    printf 'install.sh: %s is not writable; retrying with sudo\n' "$install_root"
    sudo mkdir -p "$install_root"
    sudo tar -xzf "$tmp/$asset" -C "$install_root"
    sudo chmod 0755 "$install_root"/ninfer-multicall
    bin="$install_root/ninfer"
    printf 'Installed %s\n' "$bin"
    "$bin" --help >/dev/null
    printf 'OK  %s --help\n' "$bin"
    printf 'Add %s to PATH if you want a bare "ninfer" command.\n' "$install_root"
    exit 0
  fi
fi

mkdir -p "$install_root"
tar -xzf "$tmp/$asset" -C "$install_root"
chmod 0755 "$install_root"/ninfer-multicall
bin="$install_root/ninfer"
printf 'Installed %s\n' "$bin"
"$bin" --help >/dev/null
printf 'OK  %s --help\n' "$bin"
printf 'Add %s to PATH if you want a bare "ninfer" command.\n' "$install_root"
