# Makefile for jetlag self-sched-deploy
# Interactive OCP deployment with QUADS lab assignment

SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
.PHONY: all deploy configure bootstrap repos create-assignment inventory bastion cluster clean status terminate-assignment help

# Paths
SCRIPT_DIR := $(shell pwd)
JETLAG_ROOT := $(shell cd ../.. && pwd)

# Virtual environment activation (must be after JETLAG_ROOT)
ACTIVATE_VENV := source $(JETLAG_ROOT)/.ansible/bin/activate
CONFIG_FILE := $(SCRIPT_DIR)/vars/config.env
STATE_FILE := $(SCRIPT_DIR)/vars/state.env
REPOS_DIR := $(SCRIPT_DIR)/repos
QUADS_REPO := $(REPOS_DIR)/ansible-quads-ssm

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;36m
NC := \033[0m

#------------------------------------------------------------------------------
# Main targets
#------------------------------------------------------------------------------

all: deploy

# Full deployment: prompt for ALL config upfront, then run all phases
deploy: configure bootstrap repos create-assignment-run inventory-run bastion-run cluster-run
	@echo ""
	@echo -e "$(GREEN)=============================================$(NC)"
	@echo -e "$(GREEN)Deployment Complete!$(NC)"
	@echo -e "$(GREEN)=============================================$(NC)"
	@if [ -f "$(STATE_FILE)" ]; then \
		source $(STATE_FILE) && \
		echo "Cloud: $$CLOUD_NAME" && \
		echo "Inventory: $(JETLAG_ROOT)/ansible/inventory/$$CLOUD_NAME.local"; \
	fi

# Configure: prompt for all parameters upfront
configure:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Configuration$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@$(SCRIPT_DIR)/prompt-config.sh all

#------------------------------------------------------------------------------
# Phase: Bootstrap Jetlag Environment
#------------------------------------------------------------------------------

bootstrap:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: Bootstrap Jetlag Environment$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@if [ ! -d "$(JETLAG_ROOT)/.ansible" ]; then \
		echo "Running jetlag bootstrap..."; \
		cd $(JETLAG_ROOT) && ./bootstrap.sh; \
	else \
		echo "Jetlag environment already bootstrapped."; \
	fi
	@echo -e "$(GREEN)Bootstrap complete.$(NC)"

#------------------------------------------------------------------------------
# Phase: Clone/Update Repositories
#------------------------------------------------------------------------------

repos:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: Clone/Update Repositories$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@mkdir -p $(REPOS_DIR)
	@if [ -d "$(QUADS_REPO)" ]; then \
		echo "Updating ansible-quads-ssm..."; \
		cd $(QUADS_REPO) && git pull; \
	else \
		echo "Cloning ansible-quads-ssm..."; \
		git clone https://github.com/quadsproject/ansible-quads-ssm.git $(QUADS_REPO); \
	fi
	@echo -e "$(GREEN)Repository ready.$(NC)"

#------------------------------------------------------------------------------
# Phase: QUADS Create Assignment
#------------------------------------------------------------------------------

# User-facing target: prompts for QUADS config only
create-assignment:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: QUADS Create Assignment$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@$(SCRIPT_DIR)/prompt-config.sh quads
	@$(MAKE) --no-print-directory create-assignment-run

# Internal target: runs without prompting (config must exist)
create-assignment-run:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: QUADS Create Assignment$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@set -a && source $(CONFIG_FILE) && set +a && \
	if [ "$$USE_EXISTING_ASSIGNMENT" = "true" ]; then \
		echo -e "$(YELLOW)Using existing assignment: $$CLOUD_NAME$(NC)"; \
	else \
		echo "Generating QUADS configuration..."; \
		envsubst < $(SCRIPT_DIR)/templates/quads_config.yml.j2 > $(QUADS_REPO)/quads_config.yml; \
		echo "Running QUADS assignment..."; \
		cd $(QUADS_REPO) && \
		ansible-playbook quads_self_schedule.yml \
			-e "workload_name='$$WORKLOAD_NAME'" \
			-e "num_hosts=$$NUM_HOSTS" | tee /tmp/quads_output.log; \
		CLOUD_NAME=$$(grep -oP '"cloud_name":\s*"\K[^"]+' /tmp/quads_output.log | head -1 || true); \
		if [ -z "$$CLOUD_NAME" ]; then \
			CLOUD_NAME=$$(grep -oP '"cloud":\s*\{"name":\s*"\K[^"]+' /tmp/quads_output.log | head -1 || true); \
		fi; \
		if [ -z "$$CLOUD_NAME" ]; then \
			echo -e "$(RED)Error: Could not extract cloud_name from QUADS output$(NC)"; \
			echo "Please check the output above and manually set CLOUD_NAME in $(STATE_FILE)"; \
			exit 1; \
		fi; \
		ASSIGNMENT_ID=$$(grep -oP '"assignment_id":\s*"\K[^"]+' /tmp/quads_output.log | head -1 || true); \
		if [ -z "$$ASSIGNMENT_ID" ]; then \
			ASSIGNMENT_ID=$$(grep -oP '"assignment_id":\s*\K[0-9]+' /tmp/quads_output.log | head -1 || true); \
		fi; \
		echo "CLOUD_NAME=$$CLOUD_NAME" > $(STATE_FILE); \
		echo "ASSIGNMENT_ID=$$ASSIGNMENT_ID" >> $(STATE_FILE); \
		echo -e "$(GREEN)Assignment scheduled: $$CLOUD_NAME (ID: $$ASSIGNMENT_ID)$(NC)"; \
		if [ -n "$$ASSIGNMENT_ID" ]; then \
			echo "Waiting for assignment validation..."; \
			QUADS_HOST="$$QUADS_API_SERVER"; \
			while true; do \
				STATUS=$$(curl -s "https://$$QUADS_HOST/api/v3/assignments/$$ASSIGNMENT_ID" | jq -r '.validated | tostring'); \
				if [ "$$STATUS" = "true" ]; then \
					echo -e "$(GREEN)Assignment validated and ready!$(NC)"; \
					break; \
				elif [ "$$STATUS" = "null" ] || [ -z "$$STATUS" ]; then \
					echo -e "$(YELLOW)Could not check validation status, proceeding anyway...$(NC)"; \
					break; \
				fi; \
				echo "Waiting for validation... (status: $$STATUS)"; \
				sleep 30; \
			done; \
		fi; \
		echo -e "$(GREEN)Assignment complete: $$CLOUD_NAME$(NC)"; \
	fi

#------------------------------------------------------------------------------
# Phase: Generate Jetlag Inventory
#------------------------------------------------------------------------------

# User-facing target: prompts for jetlag config only
inventory:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: Generate Jetlag Inventory$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@$(SCRIPT_DIR)/prompt-config.sh jetlag
	@$(MAKE) --no-print-directory inventory-run

# Internal target: runs without prompting (config must exist)
inventory-run:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: Generate Jetlag Inventory$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@set -a && source $(CONFIG_FILE) && source $(STATE_FILE) && set +a && \
		echo "Checking for r630 servers..."; \
		RESET_IDRAC="false"; \
		if $(SCRIPT_DIR)/check-r630.sh "$$LAB" "$$CLOUD_NAME" "$$QUADS_API_SERVER" | grep -q "r630"; then \
			echo -e "$(YELLOW)Detected r630 servers - enabling reset_idrac$(NC)"; \
			RESET_IDRAC="true"; \
		fi; \
		echo "Generating jetlag configuration..."; \
		cp $(JETLAG_ROOT)/ansible/vars/all.sample.yml $(JETLAG_ROOT)/ansible/vars/all.yml; \
		sed -i "s/^lab:$$/lab: $$LAB/" $(JETLAG_ROOT)/ansible/vars/all.yml; \
		sed -i "s/^lab_cloud:$$/lab_cloud: $$CLOUD_NAME/" $(JETLAG_ROOT)/ansible/vars/all.yml; \
		sed -i "s/^cluster_type:$$/cluster_type: $$CLUSTER_TYPE/" $(JETLAG_ROOT)/ansible/vars/all.yml; \
		sed -i "s/^worker_node_count:$$/worker_node_count: $$WORKER_NODE_COUNT/" $(JETLAG_ROOT)/ansible/vars/all.yml; \
		sed -i "s/^ocp_build: .*/ocp_build: \"$$OCP_BUILD\"/" $(JETLAG_ROOT)/ansible/vars/all.yml; \
		sed -i "s/^ocp_version: .*/ocp_version: \"$$OCP_VERSION\"/" $(JETLAG_ROOT)/ansible/vars/all.yml; \
		if [ "$$NETWORK_STACK" = "ipv4" ]; then \
			sed -i 's/^setup_bastion_registry: true$$/setup_bastion_registry: false/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
			sed -i 's/^use_bastion_registry: true$$/use_bastion_registry: false/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
		elif [ "$$NETWORK_STACK" = "ipv6" ]; then \
			sed -i '/^# Single Stack IPv6:/,/^$$/{/^# [a-z]/s/^# //; /^# - /s/^# //;}' $(JETLAG_ROOT)/ansible/vars/all.yml; \
			if [ "$$IPV6_MODE" = "disconnected" ]; then \
				sed -i 's/^setup_bastion_registry: false$$/setup_bastion_registry: true/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
				sed -i 's/^use_bastion_registry: false$$/use_bastion_registry: true/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
				echo 'sync_operator_index: true' >> $(JETLAG_ROOT)/ansible/vars/all.yml; \
				echo 'sync_ocp_release: true' >> $(JETLAG_ROOT)/ansible/vars/all.yml; \
			else \
				sed -i 's/^setup_bastion_proxy: false$$/setup_bastion_proxy: true/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
			fi; \
		elif [ "$$NETWORK_STACK" = "dual" ]; then \
			sed -i '/^# Dual Stack/,/^$$/{/^# [a-z]/s/^# //; /^# - /s/^# //;}' $(JETLAG_ROOT)/ansible/vars/all.yml; \
			sed -i 's/^setup_bastion_registry: true$$/setup_bastion_registry: false/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
			sed -i 's/^use_bastion_registry: true$$/use_bastion_registry: false/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
		fi; \
		if [ "$$RESET_IDRAC" = "true" ]; then \
			sed -i 's/^# reset_idrac: false$$/reset_idrac: true/' $(JETLAG_ROOT)/ansible/vars/all.yml; \
		fi; \
		if [ ! -f "$$PULL_SECRET_PATH" ]; then \
			echo -e "$(RED)Error: Pull secret not found at $$PULL_SECRET_PATH$(NC)"; \
			exit 1; \
		fi; \
		if [ "$$(realpath "$$PULL_SECRET_PATH")" != "$$(realpath $(JETLAG_ROOT)/pull-secret.txt)" ]; then \
			echo "Copying pull secret to jetlag root..."; \
			cp "$$PULL_SECRET_PATH" $(JETLAG_ROOT)/pull-secret.txt; \
		else \
			echo "Pull secret already in jetlag root."; \
		fi; \
		echo "Running jetlag create-inventory..."; \
		cd $(JETLAG_ROOT) && \
		$(ACTIVATE_VENV) && ansible-playbook ansible/create-inventory.yml; \
		echo -e "$(GREEN)Inventory generated: $(JETLAG_ROOT)/ansible/inventory/$$CLOUD_NAME.local$(NC)"; \
		echo ""; \
		echo "Copying SSH key to bastion host..."; \
		BASTION_HOST=$$(grep -A1 '^\[bastion\]' $(JETLAG_ROOT)/ansible/inventory/$$CLOUD_NAME.local | tail -1 | awk '{print $$1}'); \
		if [ -n "$$BASTION_HOST" ] && [ -n "$$BASTION_ROOT_PASSWORD" ]; then \
			echo "Bastion host: $$BASTION_HOST"; \
			sshpass -p "$$BASTION_ROOT_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$$BASTION_HOST 2>/dev/null && \
			echo -e "$(GREEN)SSH key copied to bastion successfully.$(NC)" || \
			echo -e "$(YELLOW)Warning: Could not copy SSH key. You may need to do this manually.$(NC)"; \
		else \
			echo -e "$(YELLOW)Warning: Bastion host or password not available. SSH key not copied.$(NC)"; \
		fi

#------------------------------------------------------------------------------
# Phase: Setup Bastion
#------------------------------------------------------------------------------

# User-facing target (no prompts needed, uses existing config)
bastion: bastion-run

# Internal target
bastion-run:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: Setup Bastion$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@source $(CONFIG_FILE) && \
	source $(STATE_FILE) && \
	echo "Running jetlag setup-bastion..."; \
	cd $(JETLAG_ROOT) && \
	$(ACTIVATE_VENV) && ansible-playbook -i ansible/inventory/$$CLOUD_NAME.local ansible/setup-bastion.yml; \
	echo -e "$(GREEN)Bastion setup complete.$(NC)"

#------------------------------------------------------------------------------
# Phase: Deploy OCP Cluster
#------------------------------------------------------------------------------

# User-facing target (no prompts needed, uses existing config)
cluster: cluster-run

# Internal target
cluster-run:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Phase: Deploy OCP Cluster$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@source $(CONFIG_FILE) && \
	source $(STATE_FILE) && \
	echo "Running jetlag $$DEPLOY_PLAYBOOK..."; \
	cd $(JETLAG_ROOT) && \
	$(ACTIVATE_VENV) && ansible-playbook -i ansible/inventory/$$CLOUD_NAME.local ansible/$$DEPLOY_PLAYBOOK; \
	echo -e "$(GREEN)Cluster deployment complete!$(NC)"; \
	echo ""; \
	BASTION_HOST=$$(grep -v '^#' $(JETLAG_ROOT)/ansible/inventory/$$CLOUD_NAME.local | grep -A1 '^\[bastion\]' | tail -1 | awk '{print $$1}'); \
	if [ "$$CLUSTER_TYPE" = "sno" ]; then \
		SNO_NAME=$$(grep -v '^#' $(JETLAG_ROOT)/ansible/inventory/$$CLOUD_NAME.local | grep -A1 '^\[sno\]' | tail -1 | awk '{print $$1}'); \
		KUBECONFIG_PATH="/root/sno/$$SNO_NAME/kubeconfig"; \
	else \
		KUBECONFIG_PATH="/root/$$CLUSTER_TYPE/kubeconfig"; \
	fi; \
	echo "Access your cluster:"; \
	echo "  ssh root@$$BASTION_HOST"; \
	echo "  export KUBECONFIG=$$KUBECONFIG_PATH"

#------------------------------------------------------------------------------
# Utility targets
#------------------------------------------------------------------------------

status:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Deployment Status$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@if [ -f "$(STATE_FILE)" ]; then \
		echo "State file: $(STATE_FILE)"; \
		cat $(STATE_FILE); \
	else \
		echo "No state file found. No active assignment."; \
	fi
	@echo ""
	@if [ -f "$(CONFIG_FILE)" ]; then \
		echo "Config file: $(CONFIG_FILE)"; \
		grep -v PASSWORD $(CONFIG_FILE) || true; \
	else \
		echo "No config file found."; \
	fi

terminate-assignment:
	@echo ""
	@echo -e "$(BLUE)=============================================$(NC)"
	@echo -e "$(BLUE)Terminate QUADS Assignment$(NC)"
	@echo -e "$(BLUE)=============================================$(NC)"
	@if [ ! -f "$(STATE_FILE)" ]; then \
		echo -e "$(RED)Error: No state file found. Nothing to release.$(NC)"; \
		exit 1; \
	fi
	@if [ ! -f "$(CONFIG_FILE)" ]; then \
		echo -e "$(RED)Error: No config file found. Cannot authenticate with QUADS.$(NC)"; \
		exit 1; \
	fi
	@source $(CONFIG_FILE) && \
	source $(STATE_FILE) && \
	if [ -z "$$ASSIGNMENT_ID" ]; then \
		echo -e "$(RED)Error: No ASSIGNMENT_ID found in state file.$(NC)"; \
		exit 1; \
	fi; \
	echo "Logging in to QUADS..."; \
	QUADS_EMAIL="$$QUADS_USERNAME@$$QUADS_USER_DOMAIN"; \
	TOKEN=$$(curl -s -X POST "https://$$QUADS_API_SERVER/api/v3/login/" \
		-u "$$QUADS_EMAIL:$$QUADS_PASSWORD" | jq -r '.auth_token // empty'); \
	if [ -z "$$TOKEN" ]; then \
		echo -e "$(RED)Error: Failed to authenticate with QUADS.$(NC)"; \
		exit 1; \
	fi; \
	echo "Terminating assignment $$ASSIGNMENT_ID (cloud: $$CLOUD_NAME)..."; \
	RESULT=$$(curl -s -k -X POST \
		-H "Authorization: Bearer $$TOKEN" \
		"https://$$QUADS_API_SERVER/api/v3/assignments/terminate/$$ASSIGNMENT_ID"); \
	echo "Response: $$RESULT"; \
	echo -e "$(GREEN)Allocation released.$(NC)"; \
	echo ""; \
	echo "Run 'make clean' to remove local state files."

clean:
	@echo ""
	@echo -e "$(YELLOW)Cleaning generated files...$(NC)"
	@rm -f $(CONFIG_FILE)
	@rm -f $(STATE_FILE)
	@rm -f /tmp/quads_output.log
	@echo -e "$(GREEN)Clean complete.$(NC)"
	@echo ""
	@echo "Note: Cloned repository in $(REPOS_DIR) was not removed."
	@echo "To remove it: rm -rf $(REPOS_DIR)"

clean-all: clean
	@echo -e "$(YELLOW)Removing cloned repository...$(NC)"
	@rm -rf $(REPOS_DIR)
	@echo -e "$(GREEN)All cleaned.$(NC)"

help:
	@echo ""
	@echo -e "$(BLUE)jetlag self-sched-deploy - Interactive OCP Deployment$(NC)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Main targets:"
	@echo "  all, deploy    Full deployment pipeline (prompts for all config upfront)"
	@echo "  configure      Prompt for all configuration parameters"
	@echo ""
	@echo "Individual phases (prompt for phase-specific config):"
	@echo "  bootstrap          Setup jetlag Python virtual environment"
	@echo "  repos              Clone/update ansible-quads-ssm repository"
	@echo "  create-assignment  QUADS assignment (prompts for QUADS config)"
	@echo "  inventory          Generate jetlag inventory (prompts for OCP config)"
	@echo "  bastion            Setup bastion node"
	@echo "  cluster            Deploy OCP cluster"
	@echo ""
	@echo "Utility targets:"
	@echo "  status               Show current deployment status"
	@echo "  terminate-assignment Terminate QUADS assignment"
	@echo "  clean                Remove generated config and state files"
	@echo "  clean-all            Remove config, state, and cloned repository"
	@echo "  help                 Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make                     # Full interactive deployment"
	@echo "  make create-assignment   # Run only QUADS assignment"
	@echo "  make inventory           # Run only inventory generation"
	@echo "  make bastion             # Run only bastion setup"
	@echo "  make cluster             # Run only cluster deployment"
	@echo ""
