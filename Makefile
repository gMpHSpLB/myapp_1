SHELL := /bin/bash


# Default target
.DEFAULT_GOAL := help
# ------------------------------ GLOBAL CONFIG --------------------------------------
RED    											:= \033[1;31m
YELLOW 											:= \033[1;33m
GREEN  											:="\033[1;32m"
CYAN   											:= \033[1;36m
RESET  											:= \033[0m

NAMESPACE_TEAM_ALPHA      						:= team-alpha
NAMESPACE_TEAM_BETA		  						:= team-beta
POD_SECURITY_ADMISSION_ENFORCEMENT_LEVEL    	:= restricted
LABEL_TEAM_1									:= alpha
LABEL_TEAM_2									:= beta

RESOURCE_QUOTA_TEAM_ALPHA_FILE					:= quotas/team-alpha-quota.yaml

# Self-documenting help: list targets with "##" comments
.PHONY: help #- Show targets
help: ## Show all available targets with short descriptions.
	# This target reads the Makefile and prints any line ending with ##.
	# Use this when you want to discover available commands quickly.
	# Expected output: a list of targets and one-line descriptions.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-28s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# Convenience wrapper to call setup Makefile targets
.PHONY: setup-minikube
setup-minikube: ## Ensure Minikube cluster is running with correct profile
	@echo -e "$(CYAN) Ensure Minikube cluster is running with correct profile $(RESET)"; \
	$(MAKE) -f Makefile_Setup ensure-minikube
	$(MAKE) -f Makefile_Setup enable-minikube-addons
	$(MAKE) -f Makefile_Setup check-clusterinfo
	$(MAKE) -f Makefile_Setup kubectl-get-nodes

.PHONY: create-namespaces-for-team-alpha-and-team-beta
create-namespaces-for-team-alpha-and-team-beta: ## Create or update namespaces for team-alpha and team-beta
	@printf '$(CYAN)%s$(RESET)\n' "Apply namespace $(NAMESPACE_TEAM_ALPHA)"
	@kubectl create namespace $(NAMESPACE_TEAM_ALPHA) --dry-run=client -o yaml | kubectl apply -f -
	@printf '$(CYAN)%s$(RESET)\n' "Apply namespace $(NAMESPACE_TEAM_BETA)"
	@kubectl create namespace $(NAMESPACE_TEAM_BETA) --dry-run=client -o yaml | kubectl apply -f -

.PHONY: assign-labels-and-pod-security-admission-enforcement-to-namespaces
assign-labels-and-pod-security-admission-enforcement-to-namespaces: ## Assign labels and Pod Security Admission enforcement to namespaces
	@printf '$(CYAN)%s$(RESET)\n' "Label namespace $(NAMESPACE_TEAM_ALPHA)"
	@kubectl label namespace $(NAMESPACE_TEAM_ALPHA) team=$(LABEL_TEAM_1) pod-security.kubernetes.io/enforce=$(POD_SECURITY_ADMISSION_ENFORCEMENT_LEVEL) --overwrite
	@printf '$(CYAN)%s$(RESET)\n' "Label namespace $(NAMESPACE_TEAM_BETA)"
	@kubectl label namespace $(NAMESPACE_TEAM_BETA) team=$(LABEL_TEAM_2) pod-security.kubernetes.io/enforce=$(POD_SECURITY_ADMISSION_ENFORCEMENT_LEVEL) --overwrite

.PHONY: delete-namespaces
delete-namespaces: ## Delete team-alpha and team-beta namespaces
	@printf '$(CYAN)%s$(RESET)\n' "Delete namespace $(NAMESPACE_TEAM_ALPHA)"
	@kubectl delete namespace $(NAMESPACE_TEAM_ALPHA) --ignore-not-found
	@printf '$(CYAN)%s$(RESET)\n' "Delete namespace $(NAMESPACE_TEAM_BETA)"
	@kubectl delete namespace $(NAMESPACE_TEAM_BETA) --ignore-not-found

.PHONY: apply-quota-to-namespace-team-alpha
apply-quota-to-namespace-team-alpha: ## Apply ResourceQuota for team-alpha namespace
	@test -f $(RESOURCE_QUOTA_TEAM_ALPHA) || (echo "Missing file: $(RESOURCE_QUOTA_TEAM_ALPHA)" && exit 1)
	@printf '$(CYAN)%s$(RESET)\n' "Apply ResourceQuota for team-alpha"
	kubectl apply -f $(RESOURCE_QUOTA_TEAM_ALPHA) 