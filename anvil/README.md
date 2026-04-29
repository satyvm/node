# Blockchain Node Reliability Lab

A fully containerized SRE simulation environment deploying a standalone Ethereum-compatible blockchain node (`anvil`) instrumented with a full Prometheus observability stack.

This project demonstrates core Site Reliability Engineering competencies:
- **Automation:** Docker Compose and Makefile deployment
- **Measurement:** Prometheus host and application-level metric scraping
- **Visualization:** Pre-provisioned Grafana dashboards
- **Alerting:** Alertmanager routing
- **Incident Response:** Pre-defined Runbooks and simulated outages.

## Architecture

Our lab is fully contained within a Docker network, making it highly portable. 
It consists of:

1. **`blockchain-node`**: Runs `anvil`, exposing JSON-RPC on port `8545`.
2. **`rpc-checker`**: A Python container constantly querying the node, measuring latency, generating small load, and exposing Prometheus metrics on `8000`.
3. **`node-exporter`**: Host OS agent to measure CPU, Memory, and Disk.
4. **`prometheus`**: The time-series metrics database querying our components.
5. **`alertmanager`**: Engine to triage alerts and fire notifications.
6. **`grafana`**: The UI rendering our time-series database metrics into dashboards.

```
(User) --> [Grafana] ---> [Prometheus] <---(metrics)--- [RPC Checker] <---> [Anvil RPC]
```

## Setup & Deployment

### Quickstart

1. Clone the repository.
2. Ensure you have Docker and Docker Compose installed.
3. Start the entire environment via Makefile:
   ```bash
   make up
   ```

### Ports
- `3000`: Grafana UI (Login: `admin` / `admin`)
- `9090`: Prometheus UI
- `9093`: Alertmanager UI
- `8545`: Anvil Blockchain RPC

## Simulating Failures

We provide commands to intentionally disrupt the environment and test the alerting rules and Docker restart policies.

**Crash the Blockchain Node**
```bash
make crash-node
```
*Expected Behavior:* The Docker daemon will auto-restart the container within seconds. If it stays down, Prometheus will fire `NodeProcessDown` and `RPCEndpointDown` after 1 minute.

**Simulate High CPU Load**
```bash
make stress-cpu
```
*Expected Behavior:* Spikes metrics. Prometheus will fire a `HighCPUUsage` alert if it sustains for 5 minutes.

## Long-term Deployment (Coolify)

This project has been explicitly engineered for easy deployment in self-hosted PaaS environments like **Coolify**. Because it uses a strictly declarative `docker-compose.yml` with relative paths and unified dependencies, it can be deployed directly from Git as a coolify stack without modification.
