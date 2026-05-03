COMPOSE ?= docker compose
ENV_FILE ?= .env

.PHONY: config up down logs smoke bench run hotaisle-provision

config:
	$(COMPOSE) --env-file $(ENV_FILE) config

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

hotaisle-provision:
	./scripts/hotaisle-provision-vm.sh
