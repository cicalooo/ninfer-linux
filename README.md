# ninfer-linux

Prebuilt **Linux x64** [NInfer-all](https://github.com/iamwavecut/ninfer-all) CLI for people who do not want to compile CUDA kernels.

This is a redistribution of upstream `ninfer-all` at commit [`63428ac`](https://github.com/iamwavecut/ninfer-all/commit/63428ac249da8a6c5d891b508d7e483d8c7def6c) (master, 25 Oct 2026) with **no local patches** (`ninfer --version` prints `0.12.0-rtx3090+2026-10-24.2-3-g63428ac`). The `--video-fps` override from earlier prebuilts is not included; see [Building the video-fps engine variant](#building-the-video-fps-engine-variant). It is **not** ComfyUI-specific. Use it from a shell, as a server, or from any frontend that can spawn `ninfer`.

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

Optional flags that this build advertises: `--spec mtp|dflash|dflash2`, `--kv-dtype int8|rk8v4|rk4v4|rk4v4-e8|rk2v4-e8`, `--vision`, `--vision-residency overlay`, `--reasoning-loop off|stop|conclude`. `--video-fps` is not in this build.

## Rebuild (this tree)

The published sm_86 binary was compiled on an RTX 3090 host (Arch, CUDA 13.4.92, GCC 15) following
upstream `docs/build-linux.md`, with the multicall option. It took about 46 minutes with `--parallel 8`
on an i9-10850K.

```bash
git clone https://github.com/iamwavecut/ninfer-all.git && cd ninfer-all
git checkout 63428ac249da8a6c5d891b508d7e483d8c7def6c
export CC=/usr/bin/gcc-15 CXX=/usr/bin/g++-15 CUDACXX=/opt/cuda/bin/nvcc CUDAHOSTCXX=/usr/bin/g++-15
cmake -S . -B build-sm86 -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_CUDA_COMPILER=$CUDACXX \
  -DCMAKE_CUDA_HOST_COMPILER=$CUDAHOSTCXX -DCMAKE_CUDA_ARCHITECTURES=86 \
  -DNINFER_BUILD_APPS=ON -DBUILD_TESTING=OFF -DNINFER_BUILD_BENCHMARKS=OFF -DNINFER_MULTICALL=ON
cmake --build build-sm86 --parallel 8
```

Since `e7b7e66` (262 upstream commits) this line adds, among others:
- tool-call parsing fixes: calls stranded in unclosed thinking are returned (`99ff511`), tool-call markers inside Markdown code stay text (`81e2989`), a quoted `</think>` needs a line break to close thinking (`7260521`)
- Chat, Responses and Anthropic requests aligned with current API specs (`420e3af`); regex/choice/GBNF constraints and strict tool arguments (`f8bb568`)
- `--reasoning-loop off|stop|conclude` (`c1378cb`); hybrid prefix cache on by default (`19d4ff0`); a cancelled prefill keeps its progress for the retry (`3ceeb54`)
- RTX 3090 cuBLAS prefill gate calibration (`5d1eaea`), a pipelined INT8 small-T attention tier (`a15f211`), first token sent before MTP drafting (`9456cb7`)
- MoE expert tiering, CPU share and streaming work; the CPU expert pool defaults to half the CPUs (`f3ae402`)
- Recursive's Flint (39.8B coding MoE) from a llama.cpp GGUF (`62eb88f`); one RoPE/YaRN resolver for every family (`b61f51f`)
- Gemma 4: a forced `tool_choice` opens the call in Gemma's own syntax (`de28692`); serve no longer applies the preset presence penalty when tools are offered (`bff41be`)
- typed decisions via `/v1/systemone` and `/v1/decisions` (`b05412a`), Qwen3.5 tensor parallelism (`230ef89`), more device profiles

## Building the video-fps engine variant

This prebuilt tracks upstream ninfer-all `master` without local patches.
The `--video-fps 1..8` override (commit `f009850`, branch `video-fps` in `~/Projects/ninfer-all`,
also `patches/0001-video-fps.patch` in cicalooo/ninfer-linux) is **not** included. To get it back,
rebuild from upstream with that commit on top and install it as a separate release:

```bash
cd ~/Projects/ninfer-all
git fetch origin
git switch -c video-fps-$(git rev-parse --short origin/master) origin/master
git cherry-pick f009850          # or: git apply /path/to/ninfer-linux/patches/0001-video-fps.patch
H=$(git rev-parse --short HEAD)
export CC=/usr/bin/gcc-15 CXX=/usr/bin/g++-15 CUDACXX=/opt/cuda/bin/nvcc CUDAHOSTCXX=/usr/bin/g++-15
cmake -S . -B build-sm86-vfps-$H -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_CUDA_COMPILER=$CUDACXX \
  -DCMAKE_CUDA_HOST_COMPILER=$CUDAHOSTCXX -DCMAKE_CUDA_ARCHITECTURES=86 \
  -DNINFER_BUILD_APPS=ON -DBUILD_TESTING=OFF -DNINFER_BUILD_BENCHMARKS=OFF -DNINFER_MULTICALL=ON
cmake --build build-sm86-vfps-$H --parallel 8

# install into its own release dir (never over an existing one)
R=/opt/ninfer-3090/releases/ninfer-all-sm86-$H-vfps
sudo install -d "$R"
sudo install -m 0755 build-sm86-vfps-$H/apps/ninfer-multicall "$R/"
for n in ninfer ninfer-serve ninfer-calibrate ninfer-perplexity ninfer-ngram-profile; do
  sudo ln -sfn ninfer-multicall "$R/$n"; done
sudo cp LICENSE NOTICE "$R/"; git rev-parse HEAD | sudo tee "$R/SOURCE_COMMIT" >/dev/null
"$R/ninfer" --version            # should end in +<hash>; `ninfer --help` should list --video-fps

# switch (stop ninfer-serve / ComfyUI's Ninferencing node first)
readlink /opt/ninfer-3090/current   # note this for rollback
sudo ln -sfn "$R" /opt/ninfer-3090/current
```

If the cherry-pick conflicts, upstream moved the video sampling code; resolve it or stay on the
plain build. The binary path may differ between revisions (`find build-sm86-vfps-$H -name ninfer-multicall`).

**Rollback:** releases are never deleted, so point `current` back at the one you noted:

```bash
/usr/bin/ls /opt/ninfer-3090/releases/
sudo ln -sfn /opt/ninfer-3090/releases/ninfer-all-sm86-<previous> /opt/ninfer-3090/current
/opt/ninfer-3090/current/ninfer --version
```

To try a release without switching, set `NINFER_EXECUTABLE=/opt/ninfer-3090/releases/<dir>/ninfer-serve`
for ninfer-agent. Note that ComfyUI's Ninferencing node also falls back to
`/opt/ninfer-3090/current/ninfer` when `NINFER_EXECUTABLE` is unset, so a switch changes its engine too.

## Video FPS (status / possible phase-out)

- **Status (25 Oct 2026):** the current engine, ninfer-all `63428ac` (`/opt/ninfer-3090/current`,
  release `v0.12.0-sm86.63428ac`), has **no `--video-fps`**. Video is sampled at the artifact's fixed 2 fps.
- **ComfyUI-Ninferencing:** its `video_fps` option (2–6) needs the older `f009850` build
  (e7b7e66 + `patches/0001-video-fps.patch`, release `v0.12.0-sm86.f009850`). At 2 (the default)
  the node omits the flag, so it works on 63428ac. Values 3–6 make the node stop with
  "this ninfer build does not advertise --video-fps".
- **To get 3–6 fps back:** rebuild the video-fps variant (see "Building the video-fps engine variant"),
  or roll back to the old build:
  `sudo ln -sfn /opt/ninfer-3090/releases/ninfer-all-sm86-f009850 /opt/ninfer-3090/current`
  (return with `sudo ln -sfn /opt/ninfer-3090/releases/ninfer-all-sm86-63428ac /opt/ninfer-3090/current`).
- **Undecided:** the `video_fps` option and the patch may be phased out later. Nothing is removed yet.

## License

Apache-2.0, same as upstream. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
