#!/usr/bin/env bash
set -euo pipefail

engine="${1:-}"
case "${engine}" in
  vllm)
    docker compose --env-file .env -f compose.max.yaml down
    docker compose --env-file .env -f compose.sglang.yaml down
    docker compose --env-file .env -f compose.yaml up -d vllm
    ;;
  max)
    docker compose --env-file .env -f compose.yaml down
    docker compose --env-file .env -f compose.sglang.yaml down
    docker compose --env-file .env -f compose.max.yaml up -d max
    ;;
  sglang)
    docker compose --env-file .env -f compose.yaml down
    docker compose --env-file .env -f compose.max.yaml down
    docker compose --env-file .env -f compose.sglang.yaml up -d sglang
    ;;
  stop)
    docker compose --env-file .env -f compose.yaml down
    docker compose --env-file .env -f compose.max.yaml down
    docker compose --env-file .env -f compose.sglang.yaml down
    ;;
  *)
    echo "Usage: $0 {vllm|max|sglang|stop}" >&2
    exit 2
    ;;
esac
