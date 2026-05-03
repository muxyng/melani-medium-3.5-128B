COMPOSE ?= docker compose
ENV_FILE ?= .env

.PHONY: config max-config sglang-config up down logs smoke bench run use-vllm use-max use-sglang stop-engines hotaisle-provision

config:
	$(COMPOSE) --env-file $(ENV_FILE) config

max-config:
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.max.yaml config

sglang-config:
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.sglang.yaml config

up:
	$(COMPOSE) --env-file $(ENV_FILE) up -d

down:
	$(COMPOSE) --env-file $(ENV_FILE) down

logs:
	$(COMPOSE) --env-file $(ENV_FILE) logs -f vllm

smoke:
	./scripts/smoke-test.sh

bench:
	./scripts/benchmark-openai.sh

run:
	./scripts/run-vllm-rocm.sh

use-vllm:
	./scripts/use-engine.sh vllm

use-max:
	./scripts/use-engine.sh max

use-sglang:
	./scripts/use-engine.sh sglang

stop-engines:
	./scripts/use-engine.sh stop

hotaisle-provision:
	./scripts/hotaisle-provision-vm.sh
