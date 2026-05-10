# ──────────────────────────────────────────────────────────────────────────────
# Ethereum Ephemery Node — Makefile
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
PROMETHEUS_IMAGE ?= prom/prometheus:v3
SHELLCHECK_IMAGE ?= koalaman/shellcheck:stable

# Resolve EC2 IP from Terraform state (silently — errors are ignored here)
IP := $(shell cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null)

.PHONY: help deploy infra-apply app-deploy sync destroy tunnel logs-execution logs-consensus status doctor sync-status prometheus-targets restart validate validate-terraform validate-compose validate-prometheus validate-shell

# ── Help ─────────────────────────────────────────────────────────────────────

help: ## Show available commands
	@echo ""
	@echo "  Ethereum Ephemery Node — Makefile Commands"
	@echo "  ==========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36mmake %-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ── Infrastructure ───────────────────────────────────────────────────────────

deploy: ## Provision AWS infra, sync config, and start the node
	@$(MAKE) infra-apply
	@$(MAKE) app-deploy

validate: validate-terraform validate-compose validate-prometheus validate-shell ## Run local validation checks
	@echo "✅ Validation passed."

infra-apply: ## Provision or update AWS infrastructure only
	@echo "🏗️  Running terraform apply..."
	cd $(TF_DIR) && terraform apply

validate-terraform: ## Check Terraform formatting and configuration
	@echo "🔎 Checking Terraform formatting..."
	@cd $(TF_DIR) && terraform fmt -check -recursive
	@echo "🔎 Validating Terraform configuration..."
	@cd $(TF_DIR) && terraform validate

validate-compose: ## Check Docker Compose renders from a clean checkout
	@echo "🔎 Validating Docker Compose config..."
	@set -e; \
	cleanup=0; \
	if [ ! -f ephemery/nodevars_env.txt ]; then \
		mkdir -p ephemery; \
		printf '%s\n' \
			'NETHERMIND_BOOTNODES=enode://placeholder@127.0.0.1:30303' \
			'BOOTNODE_ENR_LIST=enr:-placeholder' > ephemery/nodevars_env.txt; \
		cleanup=1; \
	fi; \
	trap 'if [ "$$cleanup" -eq 1 ]; then rm -f ephemery/nodevars_env.txt; rmdir --ignore-fail-on-non-empty ephemery 2>/dev/null || true; fi' EXIT; \
	docker compose --env-file ephemery/nodevars_env.txt config >/dev/null

validate-prometheus: ## Check Prometheus config and alert rules
	@echo "🔎 Validating Prometheus config and alert rules..."
	@if command -v promtool >/dev/null 2>&1; then \
		promtool check config prometheus/prometheus.yml; \
		promtool check rules prometheus/alerts/*.yml; \
	elif command -v docker >/dev/null 2>&1; then \
		docker run --rm --entrypoint promtool -v "$(CURDIR):/workspace:ro" -w /workspace $(PROMETHEUS_IMAGE) check config prometheus/prometheus.yml; \
		docker run --rm --entrypoint promtool -v "$(CURDIR):/workspace:ro" -w /workspace $(PROMETHEUS_IMAGE) check rules prometheus/alerts/*.yml; \
	else \
		echo "❌ promtool not found and Docker is unavailable."; \
		exit 1; \
	fi

validate-shell: ## Run ShellCheck on deployment scripts
	@echo "🔎 Running ShellCheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck deploy.sh prepare_ephemery.sh terraform/user_data.sh; \
	elif command -v docker >/dev/null 2>&1; then \
		docker run --rm -v "$(CURDIR):/workspace:ro" -w /workspace $(SHELLCHECK_IMAGE) deploy.sh prepare_ephemery.sh terraform/user_data.sh; \
	else \
		echo "❌ shellcheck not found and Docker is unavailable."; \
		exit 1; \
	fi

app-deploy: ## Wait for the node, sync config, and start containers
	@echo "🚀 Deploying node..."
	SSH_KEY=$(SSH_KEY) ./deploy.sh

sync: ## Wait for the node and sync config only (no container restart)
	@echo "📂 Syncing configuration only..."
	SSH_KEY=$(SSH_KEY) ./deploy.sh --sync-only

destroy: ## Tear down ALL AWS infrastructure (EC2, EBS, SG — irreversible)
	@echo "💥 Destroying infrastructure..."
	cd $(TF_DIR) && terraform destroy

restart: ## Restart all containers on the remote node (no infra changes)
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	@echo "🔄 Restarting containers..."
	ssh -i $(SSH_KEY) ubuntu@$(IP) 'cd /mnt/ethereum && docker compose --env-file ./ephemery/nodevars_env.txt up -d'

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

status: ## Show container, execution, and consensus health on the remote node
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	@echo "📦 Container status on $(IP):"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
	@echo ""
	@echo "⛏  Nethermind block number:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf -X POST -H "Content-Type: application/json" \
		--data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}" \
		http://localhost:8545 | python3 -m json.tool'
	@echo ""
	@echo "⛏  Nethermind sync status:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf -X POST -H "Content-Type: application/json" \
		--data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}" \
		http://localhost:8545 | python3 -m json.tool'
	@echo ""
	@echo "⛏  Nethermind peer count:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf -X POST -H "Content-Type: application/json" \
		--data "{\"jsonrpc\":\"2.0\",\"method\":\"net_peerCount\",\"params\":[],\"id\":1}" \
		http://localhost:8545 | python3 -m json.tool'
	@echo ""
	@echo "⛏  Nethermind chain ID:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf -X POST -H "Content-Type: application/json" \
		--data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}" \
		http://localhost:8545 | python3 -m json.tool'
	@echo ""
	@echo "🗼 Lighthouse beacon sync:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf http://localhost:5052/eth/v1/node/syncing | python3 -m json.tool'
	@echo ""
	@echo "🗼 Lighthouse peer count:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf http://localhost:5052/eth/v1/node/peer_count | python3 -m json.tool'
	@echo ""
	@echo "🔌 Engine API health from Lighthouse:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) \
		'curl -sf http://localhost:5052/eth/v1/node/syncing | python3 -m json.tool'
	@echo ""
	@echo "✅ Summary:"
	@ssh -i $(SSH_KEY) ubuntu@$(IP) "python3 -c 'import json,subprocess,urllib.request; \
rpc=lambda url,payload: json.load(urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(payload).encode(),headers={\"Content-Type\":\"application/json\"}),timeout=10)); \
http_json=lambda url: json.load(urllib.request.urlopen(url,timeout=10)); \
el_sync=rpc(\"http://localhost:8545\", {\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}); \
el_block=rpc(\"http://localhost:8545\", {\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}); \
cl_sync=http_json(\"http://localhost:5052/eth/v1/node/syncing\")[\"data\"]; \
containers=sorted(subprocess.check_output([\"docker\",\"ps\",\"--format\",\"{{.Names}}\"], text=True).splitlines()); \
summary={\"execution_rpc_ok\":\"result\" in el_sync and \"result\" in el_block, \"execution_block_number\":int(el_block[\"result\"],16) if \"result\" in el_block else None, \"consensus_ok\":cl_sync.get(\"el_offline\") is False and cl_sync.get(\"is_optimistic\") is False and cl_sync.get(\"is_syncing\") is False, \"engine_api_connected\":cl_sync.get(\"el_offline\") is False, \"containers_running\":containers}; \
print(json.dumps(summary, indent=2))'"

doctor: ## Exit nonzero if execution, consensus, or Engine API health checks fail
	@if [ -z "$(IP)" ]; then echo "❌ No active deployment found."; exit 1; fi
	@ssh -i $(SSH_KEY) ubuntu@$(IP) "python3 -c 'import json,subprocess,sys,urllib.request; \
rpc=lambda url,payload: json.load(urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(payload).encode(),headers={\"Content-Type\":\"application/json\"}),timeout=10)); \
http_json=lambda url: json.load(urllib.request.urlopen(url,timeout=10)); \
required={\"nethermind\",\"lighthouse\",\"prometheus\",\"grafana\",\"alertmanager\"}; \
containers=set(subprocess.check_output([\"docker\",\"ps\",\"--format\",\"{{.Names}}\"], text=True).splitlines()); \
missing=sorted(required-containers); \
el_sync=rpc(\"http://localhost:8545\", {\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}); \
el_block=rpc(\"http://localhost:8545\", {\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}); \
cl_sync=http_json(\"http://localhost:5052/eth/v1/node/syncing\")[\"data\"]; \
issues=[]; \
issues.extend([\"missing containers: \" + \", \".join(missing)] if missing else []); \
issues.extend([\"execution eth_syncing failed\"] if \"result\" not in el_sync else []); \
issues.extend([\"execution eth_blockNumber failed\"] if \"result\" not in el_block else []); \
issues.extend([\"engine api disconnected\"] if cl_sync.get(\"el_offline\") is not False else []); \
issues.extend([\"consensus still optimistic\"] if cl_sync.get(\"is_optimistic\") is not False else []); \
issues.extend([\"consensus still syncing\"] if cl_sync.get(\"is_syncing\") is not False else []); \
print(\"❌ doctor failed\") if issues else print(\"✅ doctor passed\"); \
[print(\"- \" + issue) for issue in issues]; \
print(json.dumps({\"execution_block_number\":int(el_block[\"result\"],16) if \"result\" in el_block else None, \"consensus_head_slot\":int(cl_sync[\"head_slot\"]), \"containers\":sorted(containers)}, indent=2)) if not issues else None; \
sys.exit(1 if issues else 0)'"

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
