# Mistral Medium 3.5 128B on MI300X with ROCm vLLM Nightly

This repository is a weightless deployment scaffold for `mistralai/Mistral-Medium-3.5-128B` on AMD MI300X using ROCm and vLLM nightly. It does not download model weights, containers, Python packages, or Hugging Face files onto this machine.

Upstream alignment checked on 2026-05-03:

- Mistral's model card recommends vLLM nightly, tensor parallel size 8, Mistral tool parsing, Mistral reasoning parsing, `max_num_batched_tokens=16384`, `max_num_seqs=128`, and `gpu_memory_utilization=0.8`: https://huggingface.co/mistralai/Mistral-Medium-3.5-128B
- The official Hugging Face `config.json` publishes this checkpoint with `quant_method: fp8` and `dtype: bfloat16`. This scaffold does not pass `--dtype`; vLLM loads the official checkpoint metadata as-is: https://huggingface.co/mistralai/Mistral-Medium-3.5-128B/raw/main/config.json
- vLLM's ROCm documentation recommends the official `vllm/vllm-openai-rocm:nightly` image and notes AMD's older `rocm/vllm` images are deprecated: https://docs.vllm.ai/en/latest/getting_started/installation/gpu/?device=rocm
- Mistral's vLLM deployment guide uses `HF_TOKEN`/`HUGGING_FACE_HUB_TOKEN` and Mistral tokenizer/config/load formats for local vLLM serving: https://docs.mistral.ai/models/deployment/local-deployment/vllm

## Files

- `compose.yaml`: Docker Compose service for the official vLLM ROCm nightly image.
- `.env.example`: deployment-time settings. Copy to `.env` on the MI300X host.
- `scripts/run-vllm-rocm.sh`: direct `docker run` equivalent for hosts not using Compose.
- `scripts/smoke-test.sh`: OpenAI-compatible API smoke test after the server is up.
- `scripts/hotaisle-provision-vm.sh`: Hot Aisle CLI wrapper for checking availability and provisioning a VM.
- `scripts/use-engine.sh`: switches the single GPU between the vLLM baseline and MAX experiment.
- `scripts/benchmark-openai.sh`: simple OpenAI-compatible completion tokens/sec benchmark.
- `cloud-init/hotaisle-vllm.yaml`: VM bootstrap that installs Docker tooling and clones this repo without starting vLLM.
- `Makefile`: small wrappers for compose config, up, logs, down, and smoke testing.

## Hardware Notes

The default configuration targets a 1x MI300X VM with `TENSOR_PARALLEL_SIZE=1`, 32k context, and conservative concurrency. The official model card also documents an 8x MI300X style deployment with `TENSOR_PARALLEL_SIZE=8`; use that shape for higher throughput or the full recommended serving profile. The official checkpoint is FP8-quantized with BF16 model dtype metadata; this is the highest-precision artifact currently published under `mistralai/Mistral-Medium-3.5-128B`. This scaffold intentionally avoids third-party GGUFs, AWQ/GPTQ variants, or manual dtype coercion.

The official model supports a 256k context window, but this deployment is configured for 32k context by default to fit the planned VM shape and reduce KV-cache pressure.

## Hot Aisle CLI Provisioning

Install the official Hot Aisle CLI on your workstation. On Linux AMD64, the release binary can be installed to `~/.local/bin`:

```bash
rm -rf /tmp/hotaisle-cli
mkdir -p /tmp/hotaisle-cli
gh release download v0.8.17 \
  --repo hotaisle/hotaisle-cli \
  --pattern 'hotaisle-cli-v0.8.17-linux-amd64.tar.gz' \
  --dir /tmp/hotaisle-cli
tar -xzf /tmp/hotaisle-cli/hotaisle-cli-v0.8.17-linux-amd64.tar.gz -C /tmp/hotaisle-cli
install -Dm755 /tmp/hotaisle-cli/hotaisle-cli-v0.8.17-linux-amd64 ~/.local/bin/hotaisle
hotaisle --version
```

Create an API key in the Hot Aisle admin TUI, then configure the CLI:

```bash
export HOTAISLE_API_TOKEN='hotaisle_api_key_here'
hotaisle config set token
hotaisle team list
hotaisle config set default-team melani
```

Upload the SSH key used for this deployment:

```bash
hotaisle user ssh-keys add --key "$(cat ~/.ssh/hotaisle_melani_medium_2026_05_03_ed25519.pub)"
```

Check available VM types:

```bash
hotaisle vm available --team melani
```

Provision a 1x MI300X VM with the cloud-init bootstrap:

```bash
./scripts/hotaisle-provision-vm.sh
```

The wrapper prints current availability first and requires typing `provision` before billing starts. It defaults to selecting by GPU shape only: 1x `MI300X`. The current API availability resolves that to 13 CPU cores, 224 GiB RAM, and about 13 TB disk.

To target the 2x MI300X shape, override the sizing:

```bash
GPU_COUNT=2 ./scripts/hotaisle-provision-vm.sh
```

The cloud-init bootstrap intentionally does not start vLLM or download model weights. It installs Docker tooling, clones this repo to `/opt/melani-medium-3.5-128B`, and leaves `/opt/melani-medium-3.5-128B/.env.pending` for secret configuration.

Default cloud-init URL:

```text
https://raw.githubusercontent.com/muxyng/melani-medium-3.5-128b/main/cloud-init/hotaisle-vllm.yaml
```

## Deployment

On the deployment host:

```bash
cp .env.example .env
$EDITOR .env
```

Set `HF_TOKEN` to a Hugging Face token with read access to the model. Make sure the model access terms have been accepted on the Hugging Face model page for that account.

Set `VLLM_API_KEY` to a random secret. Requests to the OpenAI-compatible API must send it as a bearer token.

Start with Compose:

```bash
docker compose --env-file .env up -d
docker compose --env-file .env logs -f vllm
```

Or use the direct Docker wrapper:

```bash
set -a
. ./.env
set +a
./scripts/run-vllm-rocm.sh
```

The server exposes an OpenAI-compatible API at:

```text
http://<host>:8000/v1
```

Run the smoke test after the model is loaded:

```bash
VLLM_API_KEY='your_vllm_api_key' ./scripts/smoke-test.sh
```

## Cache Placement

By default, `MODEL_CACHE_DIR=hf-cache` uses a Docker named volume. To place model and vLLM caches on a specific deployment-host mount, set an absolute path in `.env`:

```bash
MODEL_CACHE_DIR=/mnt/models/huggingface
```

This keeps downloads out of the repository while letting the deployment host reuse weights between restarts.

## Useful Runtime Knobs

- `MAX_MODEL_LEN=32768`: 32k context for the planned VM deployment. The official model supports 256k if the GPU allocation can sustain it.
- `MAX_NUM_BATCHED_TOKENS=8192`: conservative single-GPU batching default.
- `MAX_NUM_SEQS=4`: conservative single-GPU sequence concurrency default.
- `GPU_MEMORY_UTILIZATION=0.80`: model-card recommended starting point.
- `ROCR_VISIBLE_DEVICES` and `HIP_VISIBLE_DEVICES`: select AMD GPU IDs.
- `TENSOR_PARALLEL_SIZE`: should generally match the number of GPUs used by this model. The single-MI300X default is `1`; the model card's multi-GPU example uses `8`.

Because `VLLM_IMAGE` points to a nightly tag and Compose uses `pull_policy: always`, deployment will pick up the latest vLLM ROCm nightly each time the image is pulled. Pin an image digest only if you need reproducibility over freshness.

## MAX Experiment

The MAX experiment uses Modular's AMD nightly container:

```text
modular/max-amd:nightly
```

On 2026-05-03 Docker Hub also listed the concrete nightly tag `26.4.0.dev2026050306`. The experiment is isolated in `compose.max.yaml` and binds to `127.0.0.1:${MAX_PORT:-8001}` because MAX's quickstart endpoint is OpenAI-compatible but does not document an API-key flag like vLLM's `--api-key`.

Switch engines on a single-GPU VM:

```bash
./scripts/use-engine.sh vllm
./scripts/use-engine.sh max
./scripts/use-engine.sh stop
```

Benchmark whichever OpenAI-compatible endpoint is active:

```bash
BASE_URL=http://localhost:8000 VLLM_API_KEY='your_vllm_api_key' ./scripts/benchmark-openai.sh
BASE_URL=http://localhost:8001 ./scripts/benchmark-openai.sh
```

MAX's current supported-models page does not explicitly list `mistralai/Mistral-Medium-3.5-128B`. It lists related Mistral/Pixtral architectures, so this is a compatibility and performance experiment, not a guaranteed supported deployment path.
