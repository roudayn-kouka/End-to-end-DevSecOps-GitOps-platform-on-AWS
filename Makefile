# SkyForge - one-command operations.  Run `make help`.
# Requires bash, terraform, ansible, aws cli + session-manager-plugin, kubectl, kubeseal
# (all provided by the dev container in .devcontainer/).

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

TF        := terraform -chdir=terraform
TF_OUT     = $(TF) output -raw
ANSIBLE   := cd ansible && ansible-playbook --ask-vault-pass
KUBECONFIG ?= $(CURDIR)/.kube/skyforge.yaml
export KUBECONFIG

ENV ?= dev

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ----------------------------------------------------------------- setup
.PHONY: init
init: ## Personalize the repo: make init GITHUB_USER=me DOCKERHUB_USER=me
	@test -n "$(GITHUB_USER)" -a -n "$(DOCKERHUB_USER)" || { echo "GITHUB_USER and DOCKERHUB_USER are required"; exit 1; }
	scripts/init-repo.sh $(GITHUB_USER) $(DOCKERHUB_USER)

.PHONY: deps
deps: ## Install Ansible collections
	cd ansible && ansible-galaxy collection install -r requirements.yml

# ------------------------------------------------------------ infrastructure
.PHONY: bootstrap
bootstrap: ## Create the encrypted S3 state bucket (once) and write terraform/backend.hcl
	terraform -chdir=terraform/bootstrap init
	terraform -chdir=terraform/bootstrap apply
	terraform -chdir=terraform/bootstrap output -raw backend_config > terraform/backend.hcl
	$(TF) init -backend-config=backend.hcl

.PHONY: plan
plan: ## terraform plan
	$(TF) plan -out=tfplan

.PHONY: infra
infra: ## terraform apply (VPC, ALB, EC2, IAM, CloudWatch, budget)
	$(TF) apply

.PHONY: configure
configure: ## Configure every node with Ansible (Jenkins, Kubernetes, ArgoCD)
	export SSM_BUCKET="$$($(TF_OUT) ssm_bucket)" JENKINS_URL="$$($(TF_OUT) jenkins_url)"; \
	$(ANSIBLE) playbooks/site.yml

.PHONY: kubeconfig
kubeconfig: ## Download the admin kubeconfig to .kube/skyforge.yaml
	export SSM_BUCKET="$$($(TF_OUT) ssm_bucket)"; \
	$(ANSIBLE) playbooks/kubeconfig.yml

.PHONY: tunnel
tunnel: ## Forward the Kubernetes API to localhost:6443 through SSM (keep it running)
	aws ssm start-session \
	  --target "$$($(TF) output -json instance_ids | jq -r '."k8s-master"')" \
	  --document-name AWS-StartPortForwardingSession \
	  --parameters '{"portNumber":["6443"],"localPortNumber":["6443"]}'

.PHONY: seal-secrets
seal-secrets: ## Generate and seal the DB, Grafana and Slack secrets (needs `make tunnel`)
	scripts/seal-secrets.sh

# ------------------------------------------------------------------ access
.PHONY: urls
urls: ## Print the public URLs
	@echo "App     : $$($(TF_OUT) app_url)"
	@echo "Jenkins : $$($(TF_OUT) jenkins_url)"
	@echo "AWS     : $$($(TF_OUT) cloudwatch_dashboard_url)"

.PHONY: argocd-password
argocd-password: ## Print the initial ArgoCD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

.PHONY: argocd-ui
argocd-ui: ## ArgoCD UI on https://localhost:8443
	kubectl -n argocd port-forward svc/argocd-server 8443:443

.PHONY: grafana-ui
grafana-ui: ## Grafana on http://localhost:3000
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

# --------------------------------------------------------------- developer
.PHONY: test
test: ## Lint and unit-test the application
	cd app && ruff check . && ruff format --check . && pytest

.PHONY: run
run: ## Run the app + PostgreSQL locally on http://localhost:5000
	cd app && docker compose up --build

.PHONY: lint
lint: ## Run every linter (terraform, ansible, helm, app)
	$(TF) fmt -check -recursive
	cd ansible && ansible-lint
	helm lint helm/skyforge -f helm/skyforge/values-dev.yaml
	helm lint helm/skyforge -f helm/skyforge/values-prod.yaml
	$(MAKE) test

# ----------------------------------------------------------------- teardown
.PHONY: destroy
destroy: ## Destroy all AWS resources (the state bucket is kept)
	$(TF) destroy
