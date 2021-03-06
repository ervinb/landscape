# Branch-aware management of clouds, clusters, and charts.
#
# Terraform clouds use files in the terraform/ dir of the landscape repo
# Helm chart secrets are deployed through process:
#  - landscape tool pulls environment variables out of Vault
#  - env vars are fed into landscaper
#  - landscaper deploys Helm charts and their secrets
#
# Intended pipeline.
# Running any of the below commands automatically runs all those above it.
# TODO: make them mode indepdendent?
#
# Examples:
#
## Deploy local Vault + Chartmuseum containers
# make DEPLOY_LOCAL_REPOS=true \
#      SHARED_SECRETS_USERNAME=lastpass@email.addr
#      GOOGLE_STORAGE_BUCKET=helm-charts-staging-123456
#      repos
#
## Write secrets into local Vault container from LastPass
# make DEPLOY_LOCAL_REPOS=true \
#      DANGER_DEPLOY_LASTPASS_SECRETS=true \
#      SHARED_SECRETS_USERNAME=lastpass@email.addr \
#      GOOGLE_STORAGE_BUCKET=helm-charts-staging-123456 secrets
#
## Converge local minikube VM
# make CLOUD_NAME=minikube cloud
# Initialize Kubernetes cluster
# make CLUSTER_NAME=minikube cluster
# Deploy Landscaper charts
# make CLUSTER_NAME=minikube charts
#
## Quick start: Totally converge local minikube
# make DEPLOY_LOCAL_REPOS=true \
#      GOOGLE_STORAGE_BUCKET=helm-charts-staging-123456 \
#      SHARED_SECRETS_USERNAME=lastpass@email.addr \
#      DANGER_DEPLOY_LASTPASS_SECRETS=true \
#      DEBUG=true
#
## Bootstrapping from local machine
# make SHARED_SECRETS_USERNAME=lastpass@email.addr \
#      GOOGLE_STORAGE_BUCKET=helm-charts-staging-123456 \
#      DEPLOY_ONLY_NAMESPACES=openvpn,389ds \
#      CLOUD_NAME=minikube \
#      DEPLOY_LOCAL_REPOS=true \
#      DANGER_DEPLOY_LASTPASS_SECRETS=true \
#      (cloud|cluster|charts)
#
## Running with existing Vault and ChartMuseum repos (set in env vars)
#   Deploy two Chart namespaces
# make DEPLOY_ONLY_NAMESPACES=openvpn,389ds \
#      CLUSTER_NAME=gke_staging-123456_us-west1-a_master \
#      (cloud|cluster|charts)
#
#
# A Jenkins pipeline built around this looks like:
#  docker registry push -> helm chart push -> charts deploy
#
# Notes:
# Acts on single Landscape namespace at a time / Smallest CRUD unit = namespace
# Pass DEPLOY_ONLY_NAMESPACES= (csv) to avoid converging everything
# landscaper will delete manually-installed helm charts in its namespaces
# Capable of deploying from either inside or outside target cluster


DEBUG := false

SHELL := /bin/bash

# Manages deployment of clouds, clusters, charts, and LastPass secrets.
CLOUD_NAME := minikube
CLUSTER_NAME := minikube
BRANCH_NAME := $(shell git symbolic-ref HEAD 2>/dev/null | cut -d"/" -f 3)
DEPLOY_ONLY_NAMESPACES :=


# Local Deployment flags
## Pull in secrets to Vault from LastPass
DANGER_DEPLOY_LASTPASS_SECRETS := false

## Whether to start local dev-vault and dev-chartmuseum containers and retrieve
DEPLOY_LOCAL_REPOS := false

## Write LastPass secrets (via VAULT_ADDR) to non-http://127.0.0.1:8200 servers
ALLOW_REMOTE_VAULT := false

## LastPass team-shared secrets username (REQUIRED when DEPLOY_LOCAL_REPOS=true)
SHARED_SECRETS_USERNAME := 
SHARED_SECRETS_ITEM := $(BRANCH_NAME)

## GCS backend for local Helm Chart repo (REQUIRED when DEPLOY_LOCAL_REPOS=true)
GOOGLE_STORAGE_BUCKET := 

## Converge Vault container with LastPass secrets (optional)
CONVERGE_SECRETS_CMD = landscape secrets overwrite-vault-with-lastpass --secrets-username=$(SHARED_SECRETS_USERNAME) --shared-secrets-item=$(BRANCH_NAME)
ifneq (,$(DANGER_DEPLOY_LASTPASS_SECRETS))
	CONVERGE_SECRETS_CMD += --dangerous-overwrite-vault
endif


# Converge targets
## Converge Cloud cluster (e.g., minikube, terraform(GKE), unmanaged)
CONVERGE_CLOUD_CMD = landscape cloud converge --cloud=$(CLOUD_NAME)

## Converge Kubernetes cluster
CONVERGE_CLUSTER_CMD = landscape cluster converge --cluster=$(CLUSTER_NAME)

## Converge Helm charts
## Optionally, deploy a sub-set (instead of the full-set), using CSV namespaces
CONVERGE_CHARTS_CMD = landscape charts converge --cluster=$(CLUSTER_NAME)
ifneq (,$(DEPLOY_ONLY_NAMESPACES))
	CONVERGE_CHARTS_CMD += --namespaces=$(DEPLOY_ONLY_NAMESPACES)
endif


# Global landscape arguments
## Simulate convergence but not apply
ifeq ($(DRYRUN),true)
	CONVERGE_CLOUD_CMD += --dry-run
	CONVERGE_CLUSTER_CMD += --dry-run
	CONVERGE_CHARTS_CMD += --dry-run
	CONVERGE_SECRETS_CMD += --dry-run
endif

## Debug output
ifeq ($(DEBUG),true)
	CONVERGE_CLOUD_CMD += --log-level=debug
	CONVERGE_CLUSTER_CMD += --log-level=debug
	CONVERGE_CHARTS_CMD += --log-level=debug
	CONVERGE_SECRETS_CMD += --log-level=debug
endif


.PHONY: repos secrets cloud cluster charts


# Charts deployment
charts: secrets cloud cluster
	@echo - Converging Charts for CLUSTER_NAME=$(CLUSTER_NAME) CLOUD_NAME=$(CLOUD_NAME)
# deploy secrets from local repos
ifeq (true,$(DEPLOY_LOCAL_REPOS))
	VAULT_ADDR=http://127.0.0.1:8200 \
	VAULT_TOKEN=$$(docker logs dev-vault 2>&1 | grep 'Root Token' | tail -n 1 | awk '{ print $$3 }') \
	$(CONVERGE_CHARTS_CMD)
else
	$(CONVERGE_CHARTS_CMD)
endif


# Cluster deployment
cluster: secrets cloud
	@echo - Converging cluster for CLUSTER_NAME=$(CLUSTER_NAME)
	@echo   - Setting CLOUD_NAME=$(CLOUD_NAME)
ifeq (true,$(DEPLOY_LOCAL_REPOS))
	VAULT_ADDR=http://127.0.0.1:8200 \
	VAULT_TOKEN=$$(docker logs dev-vault 2>&1 | grep 'Root Token' | tail -n 1 | awk '{ print $$3 }') \
	$(CONVERGE_CLUSTER_CMD)
else
	$(CONVERGE_CLUSTER_CMD)
endif


# Cloud deployment
cloud: secrets
	@echo - Converging cloud for CLOUD_NAME=$(CLOUD_NAME)
ifeq (true,$(DEPLOY_LOCAL_REPOS))
	VAULT_ADDR=http://127.0.0.1:8200 \
	VAULT_TOKEN=$$(docker logs dev-vault 2>&1 | grep 'Root Token' | tail -n 1 | awk '{ print $$3 }') \
	$(CONVERGE_CLOUD_CMD)
else
	$(CONVERGE_CLOUD_CMD)
endif


# Secrets deployment
# Pull secrets from LastPass to local Vault container. WARNING: uses VAULT_ADDR!
secrets: repos
# fail-safe against accidentally overwriting secrets in your VAULT_ADDR host
ifeq (true,$(DANGER_DEPLOY_LASTPASS_SECRETS))
	@echo - Converging LastPass secrets into Vault
# Use local docker-based vault + chartmuseum
# as opposed to using pre-existing Vault and Helm repo values
secrets: repos
ifeq (,$(SHARED_SECRETS_USERNAME))
	$(error SHARED_SECRETS_USERNAME required to pull secrets from LastPass)
endif
ifeq (true,$(DEPLOY_LOCAL_REPOS))
	# Apply LastPass secrets to local Vault
	VAULT_ADDR=http://127.0.0.1:8200 \
	VAULT_TOKEN=$$(docker logs dev-vault 2>&1 | grep 'Root Token' | tail -n 1 | awk '{ print $$3 }') \
	$(CONVERGE_SECRETS_CMD)
else
	$(CONVERGE_SECRETS_CMD)
endif
else
	@echo - DANGER_DEPLOY_LASTPASS_SECRETS is unset. Not pulling secrets from Lastpass.
endif

# cluster boostrapping/maintenance from workstation
# start local vault and chartmuseum containers
# to deploy from outside target cluster (e.g., a laptop)
repos:
ifeq (true,$(DEPLOY_LOCAL_REPOS))
	@echo - Converging Local Repos
# use local docker-based vault + chartmuseum
# as opposed to using pre-existing Vault and Helm repo values
repos:
ifeq (,$(SHARED_SECRETS_USERNAME))
	$(error SHARED_SECRETS_USERNAME required to pull secrets from LastPass)
endif

ifeq (,$(GOOGLE_STORAGE_BUCKET))
	$(error GOOGLE_STORAGE_BUCKET required for Helm Charts repo via ChartMuseum)
endif
	# start a local vault container, if it's not already running
	$(eval DOCKER_VAULT_RUNNING := $(shell docker inspect -f '{{.State.Running}}' dev-vault))
	@if [ "$(DOCKER_VAULT_RUNNING)" != "true" ]; then \
		docker inspect dev-vault > /dev/null ; \
		if [ $$? != 0 ]; then \
			echo "dev-vault container doesnt exist. Creating it" ; \
			docker run --cap-add=IPC_LOCK -p 8200:8200 -d --name=dev-vault vault:0.9.0 ; \
			sleep 3 ; \
		else \
			echo "dev-vault container exists but not started. Starting it" ; \
			docker start dev-vault ; \
			sleep 3 ; \
		fi ; \
	else \
		echo "dev-vault container already running." ; \
	fi
	# start a local chartmuseum container, if it's not already running
	$(eval DOCKER_CHARTMUSEUM_RUNNING := $(shell docker inspect -f '{{.State.Running}}' dev-chartmuseum))
	@if [ "$(DOCKER_CHARTMUSEUM_RUNNING)" != "true" ]; then \
		docker inspect dev-chartmuseum > /dev/null ; \
		if [ $$? != 0 ]; then \
			echo "dev-chartmuseum container doesnt exist. Creating it and waiting 5s for start" ; \
			docker run -p 8080:8080 -d --name=dev-chartmuseum \
				-e GOOGLE_APPLICATION_CREDENTIALS=/creds/application_default_credentials.json \
				-v $$HOME/.config/gcloud:/creds chartmuseum/chartmuseum:v0.2.8 --port=8080 --debug \
				--storage=google --storage-google-bucket=$(GOOGLE_STORAGE_BUCKET) ; \
			sleep 5 ; \
		else \
			echo "dev-chartmuseum container exists but not started. Starting it and waiting 5s for start" ; \
			docker start dev-chartmuseum ; \
			sleep 5 ; \
		fi ; \
	else \
		echo "dev-chartmuseum container already running." ; \
	fi

	# add chartmuseum chart repo
	helm repo add chartmuseum http://127.0.0.1:8080
else
	@echo - DEPLOY_LOCAL_REPOS is unset. Skipping local container setup.
endif
