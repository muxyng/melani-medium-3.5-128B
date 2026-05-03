#!/usr/bin/env bash
set -euo pipefail

TEAM="${HOTAISLE_TEAM:-melani}"
GPU_COUNT="${GPU_COUNT:-1}"
GPU_MODEL="${GPU_MODEL:-MI300X}"
CPU_CORES="${CPU_CORES:-13}"
RAM_GB="${RAM_GB:-224}"
DISK_GB="${DISK_GB:-13000}"
USER_DATA_URL="${USER_DATA_URL:-https://raw.githubusercontent.com/muxyng/melani-medium-3.5-128b/main/cloud-init/hotaisle-vllm.yaml}"

if ! command -v hotaisle >/dev/null 2>&1; then
  echo "hotaisle CLI is not installed or not on PATH" >&2
  exit 1
fi

configured_token="$(hotaisle config get token 2>/dev/null || true)"
if [[ -z "${HOTAISLE_API_TOKEN:-}" && -z "${configured_token}" ]]; then
  echo "Set HOTAISLE_API_TOKEN, then run: hotaisle config set token" >&2
  exit 1
fi

echo "Checking Hot Aisle VM availability for team ${TEAM}..."
hotaisle vm available --team "${TEAM}"

cat <<EOF

About to provision:
  team:          ${TEAM}
  gpu:           ${GPU_COUNT}x ${GPU_MODEL}
  cpu cores:     ${CPU_CORES}
  ram gb:        ${RAM_GB}
  disk gb:       ${DISK_GB}
  user-data url: ${USER_DATA_URL}

Billing starts when this succeeds. Delete the VM to stop billing.
EOF

read -r -p "Type provision to continue: " answer
if [[ "${answer}" != "provision" ]]; then
  echo "Cancelled."
  exit 0
fi

hotaisle vm provision \
  --team "${TEAM}" \
  --cpu-cores "${CPU_CORES}" \
  --ram-gb "${RAM_GB}" \
  --disk-gb "${DISK_GB}" \
  --gpu-model "${GPU_MODEL}" \
  --gpu-count "${GPU_COUNT}" \
  --user-data-url "${USER_DATA_URL}"
