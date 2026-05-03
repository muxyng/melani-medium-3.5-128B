#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:${VLLM_PORT:-8000}}"
MODEL="${SERVED_MODEL_NAME:-mistral-medium-3.5-128b}"

echo "Checking ${BASE_URL}/v1/models"
curl -fsS "${BASE_URL}/v1/models" | jq .

echo "Sending a minimal chat completion"
curl -fsS "${BASE_URL}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg model "${MODEL}" '{
    model: $model,
    messages: [{role: "user", content: "Reply with exactly: ready"}],
    max_tokens: 8,
    temperature: 0
  }')" | jq .
