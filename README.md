# ninfer-linux

Prebuilt **Linux x64** [NInfer-all](https://github.com/iamwavecut/ninfer-all) CLI (`sm_86` focus) for people who do not want to compile CUDA kernels.

This build is based on upstream `ninfer-all` [`2caa901`](https://github.com/iamwavecut/ninfer-all/commit/2caa90160c736b4a5d3d39b8f05a92b31abe20ca) (`master`, 2026-11-24) merged with upstream [PR #468](https://github.com/iamwavecut/ninfer-all/pull/468) (`f84786d`, Ternary Bonsai 2.5 27B `gguf_ptq1_0` + `t2_g128_fp16` + PrismML MTP & Vision) plus [`patches/0002-t5-prism-compat.patch`](patches/0002-t5-prism-compat.patch) and [`patches/0003-qwen35-9b-geometry.patch`](patches/0003-qwen35-9b-geometry.patch) (`ninfer --version` prints `ninfer 2026-11-24.7+2026-11-24.7-6-g79d608ae-dirty (nvcc 13.5.37, 86)`).

The old `--video-fps` test patch (`patches/0001-video-fps.patch`) is **not** applied in this release; video sampling uses upstream's 2 fps default.

## Highlights in this release

- **Single `sm_86` engine for all `ninfer-all` models:** Qwen3.5 / 3.6 / 3.8 (dense, MoE, Flash-Next), Gemma 4, Inkling 2 Mini (+ `--spec dflash2`), DeepSeek-V4.1-Flash, Flint, Edge0.
- **Qwen3.5 9B geometry support:** [`patches/0003-qwen35-9b-geometry.patch`](patches/0003-qwen35-9b-geometry.patch) adds `Bf16Gdn9Geometry` (`[32, 4096]` GDN gating projections), `CausalD256H16Kv4` (`16` query / `4` KV head causal softmax attention), and generalized non-BF16 encoded `gdn_control_source` conversion in `tools/convert/gguf_blocks.py`.
- **Ternary Bonsai 2 & 2.5 27B (both artifact lines):**
  - Upstream `ninfer-all` format: `t2_g128_fp16` (`PQ2_0`) and `gguf_ptq1_0` (`PTQ1_0` from PR #468) with MTP / DFlash2 / Vision.
  - Community / `jgamboa` `t5_g128_fp16` format: [`patches/0002-t5-prism-compat.patch`](patches/0002-t5-prism-compat.patch) adds `t5_g128_fp16` / `ternary_row_k128_v1` + `prism_hadamard` parsing and losslessly transcodes `t5_g128_fp16` to `t2_g128_fp16` at load time, so `jgamboa/Ternary-Bonsai-2.5-27B-NInfer-4090` and `jgamboa/Ternary-Bonsai-2-27B-NInfer-4090` load directly on `sm_86` (with `--spec mtp --lm-head-draft --vision`).
- **True video & image vision (self-contained):** FFmpeg `9.0.2` (LGPL-2.1+) and `dav1d 1.5.4` (BSD-2-Clause) are compiled and statically linked into `ninfer-multicall` (H.264, HEVC, AV1, VP8, VP9, MPEG-4, MJPEG, PNG, WebP, GIF, BMP, PNM) — no external FFmpeg shared libraries are required.

## Hardware

The installer reads `nvidia-smi` and downloads the archive that matches the GPU.

| GPU | Compute | Archive | Status |
|---|---|---|---|
| RTX 30 series (3090, 3080, …) | 8.6 | `ninfer-linux-x64-sm86.tar.gz` | published |
| RTX 40 series (4090, 4080, …) | 8.9 | same sm_86 cubins | published (upstream runs sm_86 on Ada) |
| RTX 50 series, RTX PRO 6000 | 12.0 | sm_120a | **not this repo** — use [ninfer-all](https://github.com/iamwavecut/ninfer-all) / `ghcr.io/iamwavecut/ninfer-all` |

One NVIDIA GPU, Linux x64. Driver of the CUDA **13** branch (580 or newer).

## Install

```bash
curl -fsSL https://github.com/cicalooo/ninfer-linux/releases/latest/download/install.sh | bash
```

Default prefix is `/opt/ninfer`. Override it:

```bash
curl -fsSL https://github.com/cicalooo/ninfer-linux/releases/latest/download/install.sh | bash -s -- --prefix "$HOME/.local/ninfer"
```

The script checks the tarball SHA-256, unpacks `ninfer`, `ninfer-serve`, `ninfer-calibrate`, `ninfer-perplexity`, and `ninfer-ngram-profile` (one multicall binary), and runs `ninfer --help`.

### Runtime libraries

The binary is dynamically linked against system/CUDA libraries only (FFmpeg and dav1d are statically linked):

- `libcudart.so.13` and `libcublas.so.13` (CUDA 13 toolkit or matching runtime packages)
- `libcurl.so.4`, `libz.so.1`
- **glibc 2.44+** (compiled on Arch Linux; for older Debian/Ubuntu glibc releases, use upstream [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all/releases) Debian 13 builds or rebuild on your distro)

On Arch: `cuda` (or the CUDA 13 runtime libs). The NVIDIA driver is not enough by itself for `libcudart`.

## Run

Download a `.ninfer` artifact (this repo does **not** ship weights). Then:

```bash
/opt/ninfer/ninfer /path/to/model.ninfer \
  --prompt "Say hello in one short sentence." \
  --max-context 4096 --kv-capacity 4096 --max-new 32 \
  --kv-dtype int8 --no-thinking --no-cuda-graph --gdn-state-fp16
```

Serve (example with vision and MTP):

```bash
/opt/ninfer/ninfer-serve /path/to/model.ninfer \
  --host 127.0.0.1 --port 8080 \
  --max-context 65536 --kv-capacity 65536 --kv-dtype rk4v4-e8 \
  --spec mtp --draft-tokens 3 --lm-head-draft --ngram chain --vision
```

Invoke the CLI as `ninfer`, not `ninfer-multicall`. The multicall binary dispatches on `argv[0]`.

> **Note for `t5_g128_fp16` artifacts:** `patches/0002-t5-prism-compat.patch` losslessly unpacks `t5_g128_fp16` weights to `t2_g128_fp16` on device at load time (+~1.1 GiB VRAM on a 27B ternary model). `--embedding-residency host` is not supported for `t5_g128_fp16` artifacts; use default device residency.

## Rebuild (this tree)

The published `sm_86` binary was compiled on an RTX 3090 host (Arch Linux, CUDA `13.5.37`, GCC `15.3.0`, glibc `2.44`) with `meson`, `nasm`, and `NINFER_MULTICALL=ON`.

```bash
# Prerequisites on Arch: cuda, meson, nasm, ninja, cmake, pkgconf, curl, zlib, gcc15
git clone https://github.com/iamwavecut/ninfer-all.git && cd ninfer-all
git fetch origin master pull/468/head:pr-468
git checkout -b sm86-bonsai25 2caa90160c736b4a5d3d39b8f05a92b31abe20ca
git merge --no-edit pr-468
git am /path/to/ninfer-linux/patches/0002-t5-prism-compat.patch
git am /path/to/ninfer-linux/patches/0003-qwen35-9b-geometry.patch
./scripts/fetch-media-sources.sh

export CC=/usr/bin/gcc-15 CXX=/usr/bin/g++-15 CUDACXX=/opt/cuda/bin/nvcc CUDAHOSTCXX=/usr/bin/g++-15
cmake -S . -B build-sm86 -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_CUDA_COMPILER=$CUDACXX \
  -DCMAKE_CUDA_HOST_COMPILER="$CUDAHOSTCXX" -DCMAKE_CUDA_ARCHITECTURES=86 \
  -DNINFER_BUILD_APPS=ON -DBUILD_TESTING=OFF -DNINFER_BUILD_BENCHMARKS=OFF -DNINFER_MULTICALL=ON
cmake --build build-sm86 --parallel 8
```

## License

Apache-2.0, same as upstream. See [LICENSE](LICENSE), [NOTICE](NOTICE), [LICENSE-ffmpeg.txt](LICENSE-ffmpeg.txt), and [LICENSE-dav1d.txt](LICENSE-dav1d.txt).
