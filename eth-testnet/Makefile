# ──────────────────────────────────────────────────────────────────────────────
# Ethereum Sepolia Node — Makefile
#
# Usage:  make <target>       (run 'make help' to see all targets)
# Config: .env                (SSH key, Discord webhook, Grafana password)
# ──────────────────────────────────────────────────────────────────────────────

# Default SSH key — override in .env or on the command line
SSH_KEY  ?= ~/.ssh/satyvm-aws.pem

# Load .env if it exists (SSH_KEY, DISCORD_WEBHOOK_URL, GF_ADMIN_PASSWORD…)
-include .env
export

TF_DIR := terraform

# Resolve EC2 IP from Terraform state (silently — errors are ignored here)
IP := $(shell cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null)

.PHONY: help deploy destroy tunnel logs-execution logs-consensus status sync-status prometheus-targets restart

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show available commands
	@echo ""
	@echo "  Ethereum Sepolia Node — Makefile Commands"
	@echo "  ==========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Infrastructure ───────────────────────────────────────────────────────────

deploy: ## Provision AWS infra + deploy the node (reads .env for secrets)
	@echo "🏗️  Running terraform apply..."
	cd $(TF_DIR) && terraform apply
	@echo "🚀 Deploying node..."
	SSH_KEY=$(SSH_KEY) ./deploy.sh

destroy: ## Tear down ALL AWS infrastructure (EC2, EBS, SG — irreversible)
	@echo "💥 Destroying infrastructure..."
	cd $(TF_DIR) && terraform destroy

restart: ## Restart all containers on the remote node (no infra changes)
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	@echo "🔄 Restarting containers..."
	ssh -i $(SSH_KEY) ubuntu@$(IP) 'cd /mnt/ethereum && docker compose up -d'

# ── Access & Tunnels ─────────────────────────────────────────────────────────

tunnel: ## Open SSH tunnel to Grafana → http://localhost:3000
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found. Run 'make deploy' first."; exit 1; fi
	@echo "🔒 Opening secure SSH tunnel to Grafana..."
	@echo "   → Open http://localhost:3000 in your browser (login: admin / admin123)"
	@echo "   → Press Ctrl+C to close the tunnel."
	@ssh -i $(SSH_KEY) -L 3000:localhost:3000 ubuntu@$(IP)

# ── Logs ─────────────────────────────────────────────────────────────────────

logs-execution: ## Tail Nethermind (execution client) logs
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	ssh -i $(SSH_KEY) ubuntu@$(IP) 'docker logs -f nethermind'

logs-consensus: ## Tail Lighthouse (consensus client) logs
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	ssh -i $(SSH_KEY) ubuntu@$(IP) 'docker logs -f lighthouse'

# ── Monitoring & Status ─────────────────────────────────────────────────────

status: ## Show status of all containers on the remote node
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	@echo "📦 Container status on $(IP):"
	ssh -i $(SSH_KEY) ubuntu@$(IP) 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

sync-status: ## Check Nethermind + Lighthouse sync progress
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	@echo "⛏  Nethermind (eth_syncing RPC):"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf -X POST -H "Content-Type: application/json" \
		--data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}" \
		http://localhost:8545 | python3 -m json.tool'
	@echo ""
	@echo "🗼 Lighthouse beacon sync:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf http://localhost:5052/eth/v1/node/syncing | python3 -m json.tool'