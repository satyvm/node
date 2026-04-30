# Ethereum Sepolia Testnet Node

Small AWS deployment for a Sepolia node with:

- Nethermind for execution
- Lighthouse for consensus
- Grafana + Prometheus for monitoring
- Alertmanager for Discord alerts

## What This Repo Does

`make deploy` provisions the EC2 infrastructure with Terraform, copies this repo to the instance, generates the JWT secret if needed, and starts the Docker Compose stack on the server.

The node runs on Sepolia and exposes only the P2P ports publicly. RPC and dashboards stay bound to `127.0.0.1` on the host.

## Quick Start

Requirements:

- Terraform
- AWS CLI configured
- An EC2 key pair and matching private key on your machine

Set up local config:

```bash
cp .env.example .env
```

Fill in these values in `.env`:

- `DISCORD_WEBHOOK_URL`
- `SSH_KEY`
- `GF_ADMIN_PASSWORD` (optional, defaults to `admin123`)

Deploy:

```bash
make deploy
```

Open Grafana through SSH tunnel:

```bash
make tunnel
```

Then visit `http://localhost:3000`.

## Commands You'll Actually Use

```bash
make help
make deploy
make status
make sync-status
make logs-execution
make logs-consensus
make tunnel
make restart
make destroy
```

## Useful Endpoints

On the EC2 host:

- `localhost:8545` - Nethermind JSON-RPC
- `localhost:5052` - Lighthouse beacon API
- `localhost:9090` - Prometheus
- `localhost:9093` - Alertmanager
- `localhost:3000` - Grafana

Public peer-to-peer ports:

- `30303/tcp,udp` - Nethermind
- `9000/tcp,udp` - Lighthouse

## Layout

- [Makefile](/home/ubuntu/dev/node/eth-testnet/Makefile)
- [deploy.sh](/home/ubuntu/dev/node/eth-testnet/deploy.sh)
- [docker-compose.yml](/home/ubuntu/dev/node/eth-testnet/docker-compose.yml)
- [terraform/](/home/ubuntu/dev/node/eth-testnet/terraform)
- [grafana/](/home/ubuntu/dev/node/eth-testnet/grafana)
- [prometheus/](/home/ubuntu/dev/node/eth-testnet/prometheus)
- [alertmanager/](/home/ubuntu/dev/node/eth-testnet/alertmanager)
- [tempo/](/home/ubuntu/dev/node/eth-testnet/tempo)
