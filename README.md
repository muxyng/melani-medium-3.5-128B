# Mistral Medium 3.5 128B on MI300X with ROCm vLLM Nightly

This repository is a weightless deployment scaffold for `mistralai/Mistral-Medium-3.5-128B` on AMD MI300X using ROCm and vLLM nightly. It does not download model weights, containers, Python packages, or Hugging Face files onto this machine.

Upstream alignment checked on 2026-05-03:

- Mistral's model card recommends vLLM nightly, tensor parallel size 8, Mistral tool parsing, Mistral reasoning parsing, `max_num_batched_tokens=16384`, `max_num_seqs=128`, and `gpu_memory_utilization=0.8`: https://huggingface.co/mistralai/Mistral-Medium-3.5-128B
- vLLM's ROCm documentation recommends the official `vllm/vllm-openai-rocm:nightly` image and notes AMD's older `rocm/vllm` images are deprecated: https://docs.vllm.ai/en/latest/getting_started/installation/gpu/?device=rocm
- Mistral's vLLM deployment guide uses `HF_TOKEN`/`HUGGING_FACE_HUB_TOKEN` and Mistral tokenizer/config/load formats for local vLLM serving: https://docs.mistral.ai/models/deployment/local-deployment/vllm

## Files

- `compose.yaml`: Docker Compose service for the official vLLM ROCm nightly image.
- `.env.example`: deployment-time settings. Copy to `.env` on the MI300X host.
- `scripts/run-vllm-rocm.sh`: direct `docker run` equivalent for hosts not using Compose.
- `scripts/smoke-test.sh`: OpenAI-compatible API smoke test after the server is up.
- `Makefile`: small wrappers for compose config, up, logs, down, and smoke testing.

## Hardware Notes

The default configuration assumes an 8x MI300X node with `TENSOR_PARALLEL_SIZE=8`, matching the model card. This is a dense 128B model with a 256k context window; full precision serving is not a realistic single-MI300X target. For fewer GPUs, expect to lower context/concurrency significantly or use a validated quantized serving path.

## Deployment

On the deployment host:

```bash
cp .env.example .env
$EDITOR .env
```

Set `HF_TOKEN` to a Hugging Face token with read access to the model. Make sure the model access terms have been accepted on the Hugging Face model page for that account.

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
./scripts/smoke-test.sh
```

## Cache Placement

By default, `MODEL_CACHE_DIR=hf-cache` uses a Docker named volume. To place model and vLLM caches on a specific deployment-host mount, set an absolute path in `.env`:

```bash
MODEL_CACHE_DIR=/mnt/models/huggingface
```

This keeps downloads out of the repository while letting the deployment host reuse weights between restarts.

## Useful Runtime Knobs

- `MAX_MODEL_LEN=262144`: full 256k context. Lower it if KV cache pressure is too high.
- `MAX_NUM_BATCHED_TOKENS=16384`: model-card recommended batching default.
- `MAX_NUM_SEQS=128`: model-card recommended sequence concurrency default.
- `GPU_MEMORY_UTILIZATION=0.80`: model-card recommended starting point.
- `ROCR_VISIBLE_DEVICES` and `HIP_VISIBLE_DEVICES`: select AMD GPU IDs.
- `TENSOR_PARALLEL_SIZE`: should generally match the number of GPUs used by this model.

Because `VLLM_IMAGE` points to a nightly tag and Compose uses `pull_policy: always`, deployment will pick up the latest vLLM ROCm nightly each time the image is pulled. Pin an image digest only if you need reproducibility over freshness.
