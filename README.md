# ninfer-linux

Prebuilt **Linux x64** [NInfer-all](https://github.com/iamwavecut/ninfer-all) CLI for people who do not want to compile CUDA kernels.

This is a redistribution of upstream `ninfer-all` at commit [`e7b7e66`](https://github.com/iamwavecut/ninfer-all/commit/e7b7e669c47703d2c0489e4a01c5ef4dd0f87f81) (master, 2026-10-13; `ninfer --version` prints `0.12.0-rtx3090+e7b7e66`). It is **not** ComfyUI-specific. Use it from a shell, as a server, or from any frontend that can spawn `ninfer`.

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

The binary is dynamically linked. You need:

- `libcudart.so.13` and `libcublas.so.13` (CUDA 13 toolkit or the matching runtime packages)
- FFmpeg 6+ (`libavcodec`, `libavformat`, `libavutil`, `libswscale`)
- `libcurl`, glibc 2.38+

On Arch: `cuda` (or the CUDA 13 runtime libs) and `ffmpeg`. The NVIDIA driver is not enough by itself for `libcudart`.

## Run

Download a `.ninfer` artifact (this repo does **not** ship weights). Then:

```bash
/opt/ninfer/ninfer /path/to/model.ninfer \
  --prompt "Say hello in one short sentence." \
  --max-context 4096 --kv-capacity 4096 --max-new 32 \
  --kv-dtype int8 --no-thinking --no-cuda-graph --gdn-state-fp16
```

Serve:

```bash
/opt/ninfer/ninfer-serve /path/to/model.ninfer \
  --host 127.0.0.1 --port 8080 \
  --max-context 8192 --kv-capacity 8192 --kv-dtype int8 --gdn-state-fp16
```

`ninfer-all` is a **v3** engine. Ternary Bonsai 2 (`t2_g128_fp16`) needs this line, not older Don-Chad 0.6.1 builds. Model cards:

- [WaveCut/Ternary-Bonsai-2-27B-NInfer-v3](https://huggingface.co/WaveCut/Ternary-Bonsai-2-27B-NInfer-v3)
- [emiltsoi/Ternary-Bonsai-2-27B-Uncensored-Heretic-NInfer](https://huggingface.co/emiltsoi/Ternary-Bonsai-2-27B-Uncensored-Heretic-NInfer)
- Official Qwen artifacts listed in the [ninfer-all README](https://github.com/iamwavecut/ninfer-all#artifacts)

Invoke the CLI as `ninfer`, not `ninfer-multicall`. The multicall binary dispatches on `argv[0]`.

Optional flags that this build advertises: `--spec mtp|dflash|dflash2`, `--kv-dtype int8|rk8v4|rk4v4|rk4v4-e8|rk2v4-e8`, `--vision`, `--vision-residency overlay`.

## Rebuild (this tree)

The published sm_86 binary was compiled on an RTX 3090 host (Arch, CUDA 13.4.92, GCC 15) following
upstream `docs/build-linux.md`, with the multicall option. It took about 48 minutes with `--parallel 8`
on an i9-10850K.

```bash
git clone https://github.com/iamwavecut/ninfer-all.git && cd ninfer-all
git checkout e7b7e669c47703d2c0489e4a01c5ef4dd0f87f81
export CC=/usr/bin/gcc-15 CXX=/usr/bin/g++-15 CUDACXX=/opt/cuda/bin/nvcc CUDAHOSTCXX=/usr/bin/g++-15
cmake -S . -B build-sm86 -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_CUDA_COMPILER=$CUDACXX \
  -DCMAKE_CUDA_HOST_COMPILER=$CUDAHOSTCXX -DCMAKE_CUDA_ARCHITECTURES=86 \
  -DNINFER_BUILD_APPS=ON -DBUILD_TESTING=OFF -DNINFER_BUILD_BENCHMARKS=OFF -DNINFER_MULTICALL=ON
cmake --build build-sm86 --parallel 8
```

Since `8319e8f` this line adds, among others:
- Gemma 4 vision (from `877fe16e`)
- Qwen3.8-Flash-Next MTP (from `5395ec30b`)
- the Q8_0 hyper-connection format that current Flash-Next artifacts need (from `944811b5c`)
- `--version`
- the `ninfer-ngram-profile` tool

## License

Apache-2.0, same as upstream. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
