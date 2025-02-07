SHELL := /bin/bash

VERSION := 0.0.1
BUILD_INFO := Manual build

ENV_FILE := .env
ifeq ($(filter $(MAKECMDGOALS),config clean),)
	ifneq ($(strip $(wildcard $(ENV_FILE))),)
		ifneq ($(MAKECMDGOALS),config)
			include $(ENV_FILE)
			export
		endif
	endif
endif

.PHONY: help lint image push build run
.DEFAULT_GOAL := help

help: ## 💬 This help message :)
	@grep -E '[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: clean start-local deploy port-forward-local ## 🏃‍♀️ Run all the things

all-azure: deploy-azure test-azure ## 🏃‍♀️ Run all the things in Azure

####### LOCAL #############
start-local: ## 🧹 Setup local Kind Cluster
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/start-local-env.sh

deploy: ## 🚀 Deploy application resources locally
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/deploy-services-local.sh
	@echo -e "\e[34mYOU WILL NEED TO START A NEW TERMINAL AND RUN  make test\e[0m" || true

port-forward-local: ## ⏩ Forward the local port
	@echo -e "\e[34m$@\e[0m" || true
	@kubectl port-forward service/public-api-service 8080:80 --pod-running-timeout=1m0s

test: ## 🧪 Run tests, used for local development
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/test.sh

clean: ## 🧹 Clean up local files
	@echo -e "\e[34m$@\e[0m" || true
	@kind delete cluster --name azd-aks

####### AZURE #############
deploy-azure: ## 🚀 Deploy application resources in Azure
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/deploy-services-azure.sh

test-azure: ## 🧪 Run tests in Azure
	@echo -e "\e[34m$@\e[0m" || true
	@./scripts/test.sh --azure
