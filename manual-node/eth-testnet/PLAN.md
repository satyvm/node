
# Blockchain SRE Project — Complete Build Guide

---

## Overview

The goal is to build a production-grade blockchain node infrastructure that demonstrates real SRE engineering: not just getting a node running, but building the reliability, observability, automation, and resilience systems around it that make it trustworthy at scale. The stack is Ethereum (Ephemery testnet) using Nethermind as the execution client and Lighthouse as the consensus client.

**Why Nethermind over Geth:** Faster snap sync in practice, more aggressive pruning by default, better memory efficiency on smaller instances, and strong metrics support out of the box.

**Why Lighthouse:** Written in Rust, lowest memory footprint among consensus clients, and excellent checkpoint sync support that gets you to chain head in minutes rather than days.

**Why Ephemery:** Ephemery is purpose-built for validator and infrastructure rehearsal, with regular resets that force you to treat node state and recovery as operational concerns instead of one-time setup.

---

## Phase 1: Infrastructure Provisioning

### EC2 Setup

- **Instance:** `t4g.large` (2 vCPU, 8GB RAM) — Graviton ARM64, better price-to-performance for the cryptographic workloads blockchain clients require
- **Storage:** `300GB gp3` EBS — gp3 gives 3,000 baseline IOPS without paying for a larger volume size
- **AMI:** Ubuntu 22.04 LTS

### Security Group

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 22 | TCP | Your IP only | SSH |
| 30303 | TCP+UDP | 0.0.0.0/0 | Nethermind P2P |
| 9000 | TCP+UDP | 0.0.0.0/0 | Lighthouse P2P |
| 8551 | TCP | Internal only | Engine API — never expose publicly |
| 8545 | TCP | Your IP only | RPC endpoint |
| 8008 | TCP | Internal only | Nethermind metrics |

### Storage Configuration

```bash
lsblk                                    # identify your volume, usually /dev/nvme1n1
sudo mkfs -t ext4 /dev/nvme1n1
sudo mkdir -p /mnt/ethereum
sudo mount /dev/nvme1n1 /mnt/ethereum

# persist across reboots — the nofail flag lets OS boot even if volume fails to mount
echo '/dev/nvme1n1 /mnt/ethereum ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

---

## Phase 2: Software Stack

### JWT Secret

The JWT secret is the authentication bridge between the execution and consensus clients. Post-Merge Ethereum requires both clients to run together, authenticated to each other.

```bash
openssl rand -hex 32 | sudo tee /mnt/ethereum/jwtsecret
```

### `docker-compose.yml`

```yaml
version: "3.8"

services:
  execution:
    image: nethermind/nethermind:latest
    container_name: nethermind
    restart: unless-stopped
    ports:
      - "30303:30303/tcp"
      - "30303:30303/udp"
      - "8545:8545"
      - "8551:8551"
      - "8008:8008"
    volumes:
      - /mnt/ethereum/nethermind:/data
      - /mnt/ethereum/jwtsecret:/jwtsecret:ro
    command: >
      --Init.ChainSpecPath=/network/genesis.json
      --datadir=/data
      --JsonRpc.Enabled=true
      --JsonRpc.Host=0.0.0.0
      --JsonRpc.Port=8545
      --JsonRpc.EngineHost=0.0.0.0
      --JsonRpc.EnginePort=8551
      --JsonRpc.JwtSecretFile=/jwtsecret
      --Metrics.Enabled=true
      --Metrics.ExposePort=8008

  consensus:
    image: sigp/lighthouse:latest
    container_name: lighthouse
    restart: unless-stopped
    ports:
      - "9000:9000/tcp"
      - "9000:9000/udp"
      - "5054:5054"
    volumes:
      - /mnt/ethereum/lighthouse:/data
      - /mnt/ethereum/jwtsecret:/jwtsecret:ro
    command: >
      lighthouse bn
      --testnet-dir=/network
      --datadir=/data
      --execution-endpoint=http://execution:8551
      --execution-jwt=/jwtsecret
      --checkpoint-sync-url=https://checkpoint-sync.ephemery.ethpandaops.io
      --http
      --http-address=0.0.0.0
      --metrics
      --metrics-address=0.0.0.0
      --metrics-port=5054
    depends_on:
      - execution

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana

volumes:
  grafana-data:
```

### `prometheus.yml`

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'nethermind'
    static_configs:
      - targets: ['execution:8008']

  - job_name: 'lighthouse'
    static_configs:
      - targets: ['consensus:5054']
```

```bash
docker-compose up -d
docker-compose logs -f
```

---

## Phase 3: Systemd Service

Running the stack under systemd means the node survives reboots and failed starts trigger automatic restarts.

```bash
sudo nano /etc/systemd/system/ethereum-node.service
```

```ini
[Unit]
Description=Ethereum Node (Nethermind + Lighthouse)
Requires=docker.service
After=docker.service network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/home/ubuntu/ethereum-node
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable ethereum-node
sudo systemctl start ethereum-node
```

---

## Phase 4: Validation

```bash
# Is the node syncing?
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545

# Current block number (returns hex — convert with printf '%d\n' 0x<value>)
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Peer count
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  http://localhost:8545
```

---

## Phase 5: Production Hardening

### Dedicated Service User

```bash
sudo useradd --system --no-create-home --shell /bin/false nethermind
```

### UFW Firewall

```bash
sudo ufw default deny incoming
sudo ufw allow from <your-ip> to any port 22
sudo ufw allow 30303
sudo ufw allow 9000
sudo ufw enable
```

### Log Rotation

Nodes are verbose. Unchecked logs will fill your disk within days.

```json
# /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}
```

### Automated EBS Snapshots

Configure AWS Data Lifecycle Manager to snapshot your `/mnt/ethereum` volume daily. This lets you restore a fully synced node in minutes instead of re-syncing from scratch — critical at production scale across many chains.

---

## Phase 6: SLOs, SLIs, and Error Budgets

This is what separates SRE from DevOps. Define reliability goals first, then build alerting to enforce them.

### Define SLIs

- RPC success rate (non-5xx responses)
- RPC p99 latency
- Block sync lag (current block vs network head)
- Peer count
- Node uptime

### Define SLOs

```
99.9% of RPC requests succeed over a 30-day window
99.5% of RPC requests complete in < 300ms
Block lag < 5 blocks for 99% of time
Peer count > 10 for 99.5% of time
```

### Prometheus Recording Rules

```yaml
groups:
  - name: slo_rules
    rules:
      - record: job:rpc_requests:rate5m
        expr: rate(rpc_requests_total[5m])

      - record: job:rpc_errors:rate5m
        expr: rate(rpc_errors_total[5m])

      - record: job:rpc_success_rate:rate5m
        expr: 1 - (job:rpc_errors:rate5m / job:rpc_requests:rate5m)
```

### Error Budget Burn Rate Alert

Alerts before the budget is exhausted, not after.

```yaml
- alert: ErrorBudgetBurnRateHigh
  expr: job:rpc_success_rate:rate5m < 0.995
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Error budget burning fast — RPC success rate {{ $value }}"

- alert: PeerCountLow
  expr: p2p_peers < 5
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Node is isolated — peer count critically low"
```

Build a dedicated SLO dashboard in Grafana showing remaining error budget as a live percentage alongside burn rate over time.

---

## Phase 7: High Availability Cluster

Move from a single node to a load-balanced cluster with automatic failover.

```
Client
  ↓
HAProxy
  ↓        ↓        ↓
node1    node2    node3
```

### HAProxy Config

```
frontend rpc_frontend
    bind *:8545
    default_backend rpc_nodes

backend rpc_nodes
    balance roundrobin
    option httpchk POST / HTTP/1.1\r\nContent-Type:\ application/json\r\n\r\n{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}
    server node1 node1:8545 check inter 10s fall 3 rise 2
    server node2 node2:8545 check inter 10s fall 3 rise 2
    server node3 node3:8545 check inter 10s fall 3 rise 2
```

The health check hits the RPC endpoint — if a node stops responding, HAProxy automatically removes it from rotation. Zero downtime failover.

---

## Phase 8: Blockchain-Specific SRE

### Chain Reorganization Detection

Reorgs happen when the canonical chain changes — a block you considered final gets replaced. Detecting them is a reliability concern unique to blockchain infrastructure.

```python
import requests
import time

def get_block(number='latest'):
    r = requests.post('http://localhost:8545', json={
        "jsonrpc": "2.0", "method": "eth_getBlockByNumber",
        "params": [number, False], "id": 1
    })
    return r.json()['result']

prev_hash = None
prev_number = None

while True:
    block = get_block()
    current_hash = block['hash']
    current_number = int(block['number'], 16)

    if prev_hash and current_hash != prev_hash:
        print(f"REORG DETECTED at block {current_number} (depth: {prev_number - current_number + 1})")
        # push metric to Prometheus pushgateway

    prev_hash = current_hash
    prev_number = current_number
    time.sleep(12)  # ~1 Ethereum slot
```

Expose reorg events as a Prometheus metric and alert on `reorg_depth > 3`.

### RPC Abuse Simulation

Nodes in production serve many clients, some of which will abuse them with expensive calls.

```python
import asyncio
import aiohttp

async def spam_rpc(session, endpoint):
    payload = {
        "jsonrpc": "2.0",
        "method": "eth_getLogs",
        "params": [{"fromBlock": "0x0", "toBlock": "latest"}],
        "id": 1
    }
    async with session.post(endpoint, json=payload) as r:
        return r.status

async def main():
    async with aiohttp.ClientSession() as session:
        tasks = [spam_rpc(session, 'http://localhost:8545') for _ in range(500)]
        results = await asyncio.gather(*tasks)
        print(f"Success: {results.count(200)}, Failed: {results.count(429)}")

asyncio.run(main())
```

Then implement rate limiting via Nginx or Envoy in front of port 8545. The goal is graceful degradation under abuse, not a crash.

---

## Phase 9: Chaos Engineering

The thing almost no one builds. Validates that your reliability claims are actually true.

### Install Pumba

```bash
docker pull gaiaadm/pumba
```

### Experiments

**Kill a random node container:**
```bash
pumba kill --interval 30s re2:ethereum_node.*
```

**Add network latency:**
```bash
pumba netem --duration 1m delay --time 200 nethermind
```

**Simulate packet loss:**
```bash
pumba netem --duration 1m loss --percent 30 lighthouse
```

**Exhaust disk space:**
```bash
stress-ng --hdd 1 --hdd-bytes 280G --timeout 60s
```

**CPU throttling:**
```bash
stress-ng --cpu 2 --timeout 60s
```

For each experiment, document it as a structured runbook: hypothesis → expected behaviour → actual behaviour → conclusion. Run these as a scheduled **GameDay** — a quarterly exercise where you deliberately break things to validate your recovery systems.

---

## Phase 10: Infrastructure as Code

Turn everything built manually into a reproducible Terraform module.

```
terraform/
├── main.tf          # aws_instance, aws_ebs_volume, aws_security_group
├── variables.tf     # instance_type, volume_size, network, client_pair
├── outputs.tf       # public_ip, instance_id
└── user_data.sh     # mkfs, mount, docker install, compose pull, systemd enable
```

### `user_data.sh`

```bash
#!/bin/bash
mkfs -t ext4 /dev/nvme1n1
mkdir -p /mnt/ethereum
mount /dev/nvme1n1 /mnt/ethereum
echo '/dev/nvme1n1 /mnt/ethereum ext4 defaults,nofail 0 2' >> /etc/fstab

curl -fsSL https://get.docker.com | sh

git clone https://github.com/satyvm/ethereum-node-infra /opt/ethereum-node
cd /opt/ethereum-node

openssl rand -hex 32 > /mnt/ethereum/jwtsecret

systemctl enable ethereum-node
systemctl start ethereum-node
```

This becomes a **Node on Demand** system — `terraform apply` deploys a fully configured, monitored node. `terraform destroy` tears it down cleanly. At scale across 80+ chains, this is the only way to operate.

---

## Phase 11: Distributed Tracing

Metrics tell you *what* broke. Traces tell you *where* and *why*.

Add Tempo to your compose stack:

```yaml
  tempo:
    image: grafana/tempo:latest
    container_name: tempo
    ports:
      - "3200:3200"
      - "4317:4317"    # OTLP gRPC
    volumes:
      - ./tempo.yml:/etc/tempo.yml
    command: -config.file=/etc/tempo.yml
```

Instrument your RPC health-check scripts with OpenTelemetry so every probe creates a trace. In Grafana you can then correlate: metric spike → find the exact trace → see which component was slow. This is the difference between monitoring and full observability.

---

## Final Architecture

```
                        Clients
                           │
               Rate Limiter (Nginx / Envoy)
                           │
                   Load Balancer (HAProxy)
                           │
         ┌─────────────────┼─────────────────┐
       node1             node2             node3
  (Nethermind        (Nethermind        (Nethermind
  + Lighthouse)      + Lighthouse)      + Lighthouse)
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
                  Ethereum Ephemery Network
                           │
             ┌─────────────┴─────────────┐
          Prometheus                   Loki
             │                           │
        Alertmanager               Reorg Detector
             └─────────────┬─────────────┘
                        Grafana
               (SLO Dashboard + Logs + Traces)
                           │
                         Tempo
                  (Distributed Tracing)

Chaos Layer (runs independently):
  Pumba       → container kills
  tc/netem    → network degradation
  stress-ng   → disk and CPU exhaustion
```

---

## Build Roadmap

| Phase | What You Build | Key Outcome |
|---|---|---|
| 1–4 | Node + Docker + systemd | Working synced node |
| 5 | Security hardening + EBS snapshots | Production-safe baseline |
| 6 | SLOs + error budgets + burn rate alerts | SRE mindset established |
| 7 | HAProxy HA cluster | Zero downtime failover |
| 8 | Reorg detection + RPC abuse + rate limiting | Blockchain-specific depth |
| 9 | Chaos engineering + GameDay runbooks | Validated reliability |
| 10 | Terraform module | Reproducible at scale |
| 11 | OpenTelemetry + Tempo | Full observability |
