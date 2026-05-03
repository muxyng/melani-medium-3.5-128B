#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:${VLLM_PORT:-8000}}"
MODEL="${SERVED_MODEL_NAME:-mistral-medium-3.5-128b}"
MAX_TOKENS="${MAX_TOKENS:-256}"
RUNS="${RUNS:-3}"
WARMUP_TOKENS="${WARMUP_TOKENS:-64}"
API_KEY="${VLLM_API_KEY:-${OPENAI_API_KEY:-}}"

export BASE_URL MODEL MAX_TOKENS RUNS WARMUP_TOKENS API_KEY

python3 - <<'PY'
import json
import os
import time
import urllib.request

base_url = os.environ.get("BASE_URL", "http://localhost:8000").rstrip("/")
model = os.environ.get("MODEL", "mistral-medium-3.5-128b")
api_key = os.environ.get("API_KEY", "")
runs = int(os.environ.get("RUNS", "3"))
max_tokens = int(os.environ.get("MAX_TOKENS", "256"))
warmup_tokens = int(os.environ.get("WARMUP_TOKENS", "64"))
prompt = (
    "Write a continuous comma-separated sequence of short unique labels "
    "like item0001, item0002, item0003. Keep going until the token limit. "
    "Do not explain."
)

def request(tokens):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": tokens,
        "temperature": 0,
    }
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    req = urllib.request.Request(
        f"{base_url}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers=headers,
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=600) as response:
        body = response.read()
    elapsed = time.perf_counter() - start
    data = json.loads(body)
    usage = data.get("usage") or {}
    completion_tokens = int(usage.get("completion_tokens") or 0)
    total_tokens = int(usage.get("total_tokens") or 0)
    finish = data["choices"][0].get("finish_reason")
    return elapsed, completion_tokens, total_tokens, finish

print(f"endpoint={base_url} model={model}")
elapsed, completion, total, finish = request(warmup_tokens)
print(f"warmup elapsed={elapsed:.2f}s completion_tokens={completion} tok/s={completion / elapsed:.2f} finish={finish}")

rates = []
for idx in range(1, runs + 1):
    elapsed, completion, total, finish = request(max_tokens)
    rate = completion / elapsed
    rates.append(rate)
    print(f"run{idx} elapsed={elapsed:.2f}s completion_tokens={completion} total_tokens={total} tok/s={rate:.2f} finish={finish}")

print(f"avg_completion_tok_s={sum(rates) / len(rates):.2f}")
PY
