SHELL := /bin/bash

# Default target
.DEFAULT_GOAL := help

# ------------------------------ GLOBAL CONFIG --------------------------------------
RED    := \033[1;31m
YELLOW := \033[1;33m
GREEN  := \033[1;32m
CYAN   := \033[1;36m
RESET  := \033[0m

# Self-documenting help: list targets with "##" comments
.PHONY: help
help: ## Show all available targets with short descriptions.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-72s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# Convenience wrapper to call setup Makefile targets
.PHONY: setup-minikube
setup-minikube: ## Ensure Minikube cluster is running with correct profile
	@echo -e "$(CYAN) Ensure Minikube cluster is running with correct profile $(RESET)"; \
	$(MAKE) -f Makefile_Setup ensure-minikube
	$(MAKE) -f Makefile_Setup enable-minikube-addons
	$(MAKE) -f Makefile_Setup check-clusterinfo
	$(MAKE) -f Makefile_Setup kubectl-get-nodes

# ------------------------------------------------------------------------------------------------------------
#                               Kubernetes RBAC and Namespace Isolation Playbook
#                         Using: Minikube, namespaces team-alpha / team-beta
# ------------------------------------------------------------------------------------------------------------
.PHONY: run-rbac-namespace-isolation-playbook
run-rbac-namespace-isolation-playbook: setup-minikube ## Walk through Sections 2–7: namespaces, RBAC, SA, aggregation, audit
	@printf '$(CYAN)%s$(RESET)\n' \
		" This will:" \
		"   - Step 0. Clean up any previous run." \
		"   - Step 1. Create namespaces team-alpha and team-beta." \
		"   - Step 2. Label namespaces and enforce Pod Security Admission (restricted)." \
		"   - Step 2b. Apply ResourceQuota for team-alpha." \
		"   - Step 2c. Verify namespaces, labels, PodSecurity, and quota." \
		"   - Step 3. Apply namespace-scoped Roles and RoleBindings for team-alpha." \
		"   - Step 3b. Verify namespace-scoped RBAC objects exist." \
		"   - Step 4. Apply aggregated ClusterRole and extended view RoleBinding." \
		"   - Step 4b. Verify aggregated ClusterRole label and RoleBinding." \
		"   - Step 5. Apply myapp ServiceAccount + Deployment and default SA hardening." \
		"   - Step 5b. Verify myapp SA/Deployment and default SA hardening." \
		"   - Step 6. Apply deploy-bot ServiceAccount + RBAC for rollout operations." \
		"   - Step 6b. Verify deploy-bot SA/Role/RoleBinding." \
		"   - Step 7. Run RBAC audit checklist (assert allow + assert deny)."; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to continue..."; \
	read -r _

	@printf '$(CYAN)%s$(RESET)\n' "Step 0. Cleanup previous run"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 0..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC cleanup-rbac-namespace-isolation-playbook

	@printf '$(CYAN)%s$(RESET)\n' "Step 1. Create namespaces team-alpha and team-beta"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 1..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC create-namespaces-for-team-alpha-and-team-beta

	@printf '$(CYAN)%s$(RESET)\n' "Step 2. Label namespaces and apply Pod Security Admission"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 2..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC assign-labels-and-pod-security-admission-enforcement-to-namespaces

	@printf '$(CYAN)%s$(RESET)\n' "Step 2b. Apply ResourceQuota for team-alpha"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 2b..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC apply-quota-to-namespace-team-alpha

	@printf '$(CYAN)%s$(RESET)\n' "Step 2c. Verify namespaces, labels, PodSecurity, and quota"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 2c..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC verify-namespaces-and-pod-security
	@$(MAKE) -f Makefile_Quota_RBAC verify-quota-team-alpha

	@printf '$(CYAN)%s$(RESET)\n' "Step 3. Apply namespace-scoped RBAC (developer/viewer Roles + RoleBindings for team-alpha)"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 3..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC apply-rbac-role-to-namespace-team-alpha
	@$(MAKE) -f Makefile_Quota_RBAC apply-rbac-viewer-role-to-namespace-team-alpha
	@$(MAKE) -f Makefile_Quota_RBAC apply-rbac-developer-rolebinding-to-namespace-team-alpha

	@printf '$(CYAN)%s$(RESET)\n' "Step 3b. Verify namespace-scoped RBAC objects exist"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 3b..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC verify-namespace-rbac-team-alpha

	@printf '$(CYAN)%s$(RESET)\n' "Step 4. Apply aggregated ClusterRole and extended view RoleBinding"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 4..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC apply-rbac-platform-observability

	@printf '$(CYAN)%s$(RESET)\n' "Step 4b. Verify aggregated ClusterRole label and RoleBinding"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 4b..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC verify-platform-observability-rbac

	@printf '$(CYAN)%s$(RESET)\n' "Step 5. Apply myapp ServiceAccount + Deployment and default SA hardening"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 5..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC apply-myapp-serviceaccount-and-deployment
	@$(MAKE) -f Makefile_Quota_RBAC apply-a-default-serviceaccount-with-automountserviceaccounttoken-false-in-team-alpha-namespace

	@printf '$(CYAN)%s$(RESET)\n' "Step 5b. Verify myapp SA/Deployment and default SA hardening"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 5b..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC verify-myapp-serviceaccount-and-deployment
	@$(MAKE) -f Makefile_Quota_RBAC verify-default-serviceaccount-hardening-team-alpha

	@printf '$(CYAN)%s$(RESET)\n' "Step 6. Apply deploy-bot ServiceAccount, Role, and RoleBinding"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 6..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC apply-deploy-bot-rbac

	@printf '$(CYAN)%s$(RESET)\n' "Step 6b. Verify deploy-bot SA/Role/RoleBinding"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 6b..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC verify-deploy-bot-rbac

	@printf '$(CYAN)%s$(RESET)\n' "Step 7. Run RBAC audit checklist (assert allow + assert deny)"; \
	printf '$(CYAN)%s$(RESET)\n' "Press ENTER to run Step 7..."; read -r _
	@$(MAKE) -f Makefile_Quota_RBAC rbac-audit-checklist