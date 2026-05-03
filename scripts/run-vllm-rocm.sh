#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${HF_TOKEN:-}" ]]; then
  echo "HF_TOKEN is required and must have access to mistralai/Mistral-Medium-3.5-128B" >&2
  exit 1
fi
if [[ -z "${VLLM_API_KEY:-}" ]]; then
  echo "VLLM_API_KEY is required for the public OpenAI-compatible API" >&2
  exit 1
fi

VLLM_IMAGE="${VLLM_IMAGE:-vllm/vllm-openai-rocm:nightly}"
MODEL_ID="${MODEL_ID:-mistralai/Mistral-Medium-3.5-128B}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-mistral-medium-3.5-128b}"
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-hf-cache}"
VLLM_PORT="${VLLM_PORT:-8000}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-1}"
ROCR_VISIBLE_DEVICES="${ROCR_VISIBLE_DEVICES:-0}"
HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES:-$ROCR_VISIBLE_DEVICES}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-32768}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.80}"
MAX_NUM_BATCHED_TOKENS="${MAX_NUM_BATCHED_TOKENS:-8192}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-4}"

docker run --rm --pull always \
  --name mistral-medium-35-vllm \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add video \
  --group-add render \
  --ipc=host \
  --cap-add SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -p "${VLLM_PORT}:8000" \
  -v "${MODEL_CACHE_DIR}:/models/huggingface" \
  -e HF_TOKEN="${HF_TOKEN}" \
  -e HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}" \
  -e HF_HOME=/models/huggingface \
  -e HF_HUB_CACHE=/models/huggingface/hub \
  -e VLLM_CACHE_ROOT=/models/huggingface/vllm \
  -e ROCR_VISIBLE_DEVICES="${ROCR_VISIBLE_DEVICES}" \
  -e HIP_VISIBLE_DEVICES="${HIP_VISIBLE_DEVICES}" \
  -e PYTORCH_HIP_ALLOC_CONF="${PYTORCH_HIP_ALLOC_CONF:-expandable_segments:True}" \
  "${VLLM_IMAGE}" \
  --host 0.0.0.0 \
  --port 8000 \
  --api-key "${VLLM_API_KEY}" \
  --model "${MODEL_ID}" \
  --served-model-name "${SERVED_MODEL_NAME}" \
  --download-dir /models/huggingface \
  --max-model-len "${MAX_MODEL_LEN}" \
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
  --max-num-batched-tokens "${MAX_NUM_BATCHED_TOKENS}" \
  --max-num-seqs "${MAX_NUM_SEQS}" \
  --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}" \
  --config-format mistral \
  --load-format mistral \
  --tokenizer-mode mistral \
  --tool-call-parser mistral \
  --reasoning-parser mistral \
  --enable-auto-tool-choice
