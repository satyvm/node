# Ethereum Sepolia Testnet Node

A production-grade, fully containerized Ethereum Sepolia testnet node running Nethermind (execution) + Lighthouse (consensus) with a complete SRE observability stack.

**Architecture:** AWS EC2 `t4g.large` (ARM64 / Graviton3) — all images are multi-arch and fully ARM64 compatible.

---

## Stack

| Component | Image | Role |
|---|---|---|
| **Nethermind** | `nethermind/nethermind` | Execution client (EL) — processes transactions, EVM |
| **Lighthouse** | `sigp/lighthouse` | Consensus client (CL) — follows the beacon chain |
| **Prometheus** | `prom/prometheus` | Metrics collection & alerting rules |
| **Grafana** | `grafana/grafana` | Dashboards & visualisation |
| **Tempo** | `grafana/tempo` | Distributed tracing backend |
| **Alertmanager** | `prom/alertmanager` | Routes alerts → Discord |
| **Node Exporter** | `prom/node-exporter` | EC2 host metrics (CPU, RAM, Disk) |
| **cAdvisor** | `gcr.io/cadvisor/cadvisor` | Docker container resource metrics |

---

## Port Reference

### 🌐 Publicly Exposed (Security Group: open to internet)

These ports **must** be open to the internet so the nodes can find peers on the Sepolia network.

| Port | Protocol | Container | Purpose |
|------|----------|-----------|---------|
| `30303` | TCP + UDP | `nethermind` | Nethermind P2P peer discovery and block propagation |
| `9000` | TCP + UDP | `lighthouse` | Lighthouse P2P peer discovery and attestation gossip |
| `22` | TCP | Host (EC2) | SSH access — restricted to your IP via Security Group |

### 🔒 Host-Local Only (bound to `127.0.0.1` — NOT reachable from internet)

These ports are accessible only on the EC2 instance itself. Use `make tunnel` to securely forward them to your local machine over SSH.

| Port | Container | Purpose |
|------|-----------|---------|
| `8545` | `nethermind` | JSON-RPC API — query blockchain state, send transactions |
| `9090` | `prometheus` | Prometheus UI and API |
| `9093` | `alertmanager` | Alertmanager UI |
| `3000` | `grafana` | Grafana dashboard — access via `make tunnel` |
| `3200` | `tempo` | Tempo HTTP API (query traces) |
| `4317` | `tempo` | Tempo OTLP gRPC ingest endpoint |

### 🐳 Internal Docker Network Only (not published to host at all)

These ports exist only inside the Docker network. Containers talk to each other directly; nothing outside Docker can reach them.

| Port | Container | Accessed By | Purpose |
|------|-----------|-------------|---------|
| `8551` | `nethermind` | `lighthouse` | Engine API — JWT-authenticated consensus↔execution handshake |
| `8008` | `nethermind` | `prometheus` | Nethermind Prometheus metrics endpoint |
| `5054` | `lighthouse` | `prometheus` | Lighthouse Prometheus metrics endpoint |
| `9100` | `node-exporter` | `prometheus` | Host OS metrics (CPU, RAM, disk, network) |
| `8080` | `cadvisor` | `prometheus` | Docker container resource metrics |

---

## Grafana Dashboards

Dashboards are auto-provisioned on startup into three folders:

| Folder | Dashboards | Source |
|---|---|---|
| **Ethereum / Execution** | Nethermind overview | [NethermindEth/metrics-infrastructure](https://github.com/NethermindEth/metrics-infrastructure) |
| **Ethereum / Consensus** | 20 Lighthouse dashboards (Attestation, Network, Fork Choice, Sync…) | [sigp/lighthouse-metrics](https://github.com/sigp/lighthouse-metrics) |
| **System** | Node Exporter Full (ID: 1860), cAdvisor (ID: 14282) | Grafana community |

---

## Quick Start

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform installed (`terraform --version`)
- SSH key pair `satyvm-aws` created in AWS `us-east-1`
- `.env` file created from `.env.example` with your Discord webhook URL and SSH key path

### Deploy
```bash
# 1. Copy and fill in secrets
cp .env.example .env
# Edit .env: set DISCORD_WEBHOOK_URL and SSH_KEY

# 2. Provision AWS infrastructure + deploy node
make deploy
```

### Access Grafana (Securely)
```bash
make tunnel
# Then open http://localhost:3000 in your browser (admin / admin)
```

### Other Commands
```bash
make status           # Show all container statuses
make logs-execution   # Tail Nethermind logs
make logs-consensus   # Tail Lighthouse logs
make destroy          # Tear down all AWS infrastructure
```

### Verify the Node is Syncing
Once SSHed in (or via `make tunnel`), check the Lighthouse logs:
```bash
# Should show "Connected to execution engine" and slot numbers increasing
docker logs -f lighthouse

# Check sync progress via RPC
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```
If `eth_syncing` returns `false`, your node is fully synced!

---

## Project Structure

```
eth-testnet/
├── Makefile                      # Operational commands
├── deploy.sh                     # Deployment automation
├── docker-compose.yml            # All services
├── .env.example                  # Secret template (copy to .env)
├── .gitignore
│
├── terraform/                    # AWS infrastructure (EC2, Security Group, EBS)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── user_data.sh              # EC2 boot script (Docker install, disk format/mount)
│
├── prometheus/
│   └── prometheus.yml            # Scrape configs for all services
├── alertmanager/
│   └── alertmanager.yml          # Discord webhook routing (uses ${DISCORD_WEBHOOK_URL})
├── tempo/
│   └── tempo.yaml                # Distributed tracing config
│
└── grafana/
    ├── provisioning/
    │   ├── dashboards/dashboard.yml   # Auto-load dashboard folders
    │   └── datasources/datasource.yml # Prometheus + Tempo datasources
    └── dashboards/
        ├── nethermind/           # Official Nethermind dashboard
        ├── lighthouse/           # 20 official Lighthouse dashboards
        └── system/               # Node Exporter + cAdvisor dashboards
```

---

## ARM64 Compatibility

All images in this stack publish official **multi-arch manifests** supporting `linux/arm64`. The EC2 `t4g.large` (AWS Graviton3) will automatically pull the correct ARM64 layer.

| Image | ARM64 Status |
|---|---|
| `nethermind/nethermind` | ✅ Official ARM64 build |
| `sigp/lighthouse` | ✅ Official ARM64 build |
| `prom/prometheus` | ✅ Multi-arch |
| `prom/alertmanager` | ✅ Multi-arch |
| `prom/node-exporter` | ✅ Multi-arch |
| `gcr.io/cadvisor/cadvisor` | ✅ Multi-arch |
| `grafana/grafana` | ✅ Multi-arch |
| `grafana/tempo` | ✅ Multi-arch (stable release tags only) |

> **Important:** Only use stable release tags (e.g. `v2.10.1`). Development/nightly tags like `main-33fb7ac` are single-arch CI builds and may not have an ARM64 layer.

---

## Data Storage

Blockchain data is stored on a dedicated 300GB `gp3` EBS volume mounted at `/mnt/ethereum` on the EC2 instance. Docker bind-mounts map into this volume:

| Path on EC2 | Container | Contents | Estimated Size (Sepolia) |
|---|---|---|---|
| `/mnt/ethereum/data/nethermind` | `nethermind` | Execution chain data | ~150 GB |
| `/mnt/ethereum/data/lighthouse` | `lighthouse` | Beacon chain data | ~80 GB |

Named Docker volumes (Prometheus metrics, Grafana dashboards state, Alertmanager state, Tempo traces) are stored in Docker's default volume directory (`/var/lib/docker/volumes/`) on the 20GB root volume.
