COMPOSE ?= docker compose
ENV_FILE ?= .env

.PHONY: config max-config up down logs smoke bench run use-vllm use-max stop-engines hotaisle-provision

config:
	$(COMPOSE) --env-file $(ENV_FILE) config

max-config:
	$(COMPOSE) --env-file $(ENV_FILE) -f compose.max.yaml config

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

stop-engines:
	./scripts/use-engine.sh stop

hotaisle-provision:
	./scripts/hotaisle-provision-vm.sh
