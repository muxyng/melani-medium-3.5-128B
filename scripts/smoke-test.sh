#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:${VLLM_PORT:-8000}}"
MODEL="${SERVED_MODEL_NAME:-mistral-medium-3.5-128b}"

echo "Checking ${BASE_URL}/v1/models"
if command -v jq >/dev/null 2>&1; then
  curl -fsS "${BASE_URL}/v1/models" | jq .
else
  curl -fsS "${BASE_URL}/v1/models"
  echo
fi

echo "Sending a minimal chat completion"
payload='{"model":"'"${MODEL}"'","messages":[{"role":"user","content":"Reply with exactly: ready"}],"max_tokens":8,"temperature":0}'
if command -v jq >/dev/null 2>&1; then
  curl -fsS "${BASE_URL}/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "${payload}" | jq .
else
  curl -fsS "${BASE_URL}/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "${payload}"
  echo
fi
