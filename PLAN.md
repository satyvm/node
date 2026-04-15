# Blockchain Node Reliability Lab

## Goal

Build a one-day project that demonstrates the core responsibilities of a Blockchain Site Reliability Engineer:

- run a blockchain node service
- monitor system and application health
- detect failures with alerts
- automate recovery
- document incidents and operations

This project is intentionally scoped to fit a low budget and one full day of work. The focus is reliability engineering, not syncing a large mainnet node.

## Project Summary

Create a small lab environment around a local Ethereum-compatible node using `hardhat node` or `anvil`, then add:

- Prometheus for metrics collection
- Grafana for dashboards
- Alertmanager for alert routing
- `node_exporter` for host-level metrics
- a custom RPC health-check exporter in Python or Bash
- a restart/recovery mechanism using `systemd` or a watchdog script
- documentation for setup, alerts, incidents, and recovery

## Final Deliverable

By the end of the day, the repo should contain:

- a runnable local blockchain node
- monitoring config
- alerting config
- one dashboard
- one health-check script
- one recovery script or systemd service
- a README with setup and architecture
- a runbook
- one short incident postmortem

## Recommended Scope

### Minimum viable version

If time becomes tight, complete this version:

- local blockchain node running
- Prometheus scraping `node_exporter`
- custom RPC health check
- Grafana dashboard
- 3 alert rules
- process restart on failure
- README + runbook

### Strong version

If execution goes smoothly, add:

- Alertmanager email or webhook notifications
- simulated failure drills with screenshots
- latency metric for RPC requests
- incident timeline and postmortem

## Suggested Architecture

### Services

- `blockchain-node`: local node process using `hardhat node` or `anvil`
- `node-exporter`: host metrics
- `prometheus`: scrapes node exporter and custom app metrics
- `alertmanager`: receives alerts from Prometheus
- `grafana`: visualizes host and RPC health
- `rpc-checker`: custom script that probes the RPC endpoint

### Data flow

1. Blockchain node exposes RPC on localhost.
2. Health-check script polls the RPC endpoint.
3. Health-check script exposes metrics or writes status for Prometheus scraping.
4. Prometheus evaluates alert rules.
5. Alertmanager routes notifications.
6. Grafana displays uptime, latency, CPU, memory, and incidents.
7. Watchdog or systemd restarts the node if it crashes.

## Exact One-Day Plan

## 1. 09:00-09:45 Setup Workspace

Create a clean working structure:

```text
node/
  PLAN.md
  README.md
  docker-compose.yml
  prometheus/
    prometheus.yml
    alerts.yml
  alertmanager/
    alertmanager.yml
  grafana/
    dashboards/
  scripts/
    rpc_check.py
    restart_node.sh
    simulate_failure.sh
  docs/
    RUNBOOK.md
    INCIDENT.md
```

Tasks:

- decide whether to use local machine or cheap VPS
- install Docker and Docker Compose, or use native binaries
- choose the blockchain node runtime:
  - preferred: `hardhat node`
  - alternative: `anvil`
- initialize repo structure

Success criteria:

- project folders exist
- node process can be started manually

## 2. 09:45-10:45 Get Node Running

Primary option:

- install Node.js
- initialize a minimal Hardhat project
- run `npx hardhat node`

Alternative:

- install Foundry
- run `anvil`

Tasks:

- confirm local RPC endpoint works
- test using `curl` with a basic JSON-RPC request such as `eth_blockNumber`
- document the command used to start the node

Success criteria:

- RPC responds on localhost
- process is stable for at least 5 to 10 minutes

## 3. 10:45-12:00 Add Host Monitoring

Install and run:

- Prometheus
- node_exporter
- Grafana

Tasks:

- configure Prometheus to scrape:
  - itself
  - node_exporter
- start Grafana
- import or build a basic dashboard for:
  - CPU
  - memory
  - disk
  - network
  - uptime

Metrics to display:

- CPU utilization
- memory usage
- disk space available
- load average
- host uptime

Success criteria:

- Prometheus targets show healthy
- Grafana dashboard loads data

## 4. 12:00-13:30 Add Blockchain RPC Health Monitoring

Write `scripts/rpc_check.py` or equivalent Bash script.

The script should:

- send a JSON-RPC request to the local node every few seconds
- verify response success
- measure latency
- expose metrics in a Prometheus-friendly way

Recommended metrics:

- `rpc_up`
- `rpc_response_seconds`
- `rpc_request_failures_total`
- `rpc_last_success_timestamp`

Implementation options:

- simple HTTP exporter on a custom port
- textfile collector format for node_exporter

Success criteria:

- Prometheus scrapes custom RPC metrics
- Grafana can show RPC health and latency

## 5. 13:30-14:30 Add Alert Rules

Create `prometheus/alerts.yml`.

Required alerts:

- `NodeProcessDown`
- `RPCEndpointDown`
- `HighCPUUsage`
- `HighMemoryUsage`
- `DiskSpaceLow`

Suggested thresholds:

- CPU above 85 percent for 5 minutes
- memory above 85 percent for 5 minutes
- disk free below 15 percent
- RPC probe failure for 1 minute
- process absent for 1 minute

For each alert, define:

- alert name
- expression
- duration
- labels
- annotations with clear summary and action hint

Success criteria:

- alerts appear in Prometheus
- at least one test alert can be triggered on demand

## 6. 14:30-15:15 Add Alertmanager

Configure `alertmanager/alertmanager.yml`.

Choose one output:

- email
- Discord webhook
- Slack webhook
- local webhook receiver

Tasks:

- point Prometheus to Alertmanager
- group alerts by severity or service
- define a default receiver

Success criteria:

- firing alert is visible in Alertmanager
- at least one notification is delivered or logged

## 7. 15:15-16:15 Add Recovery Automation

Implement one of these:

### Option A: systemd

- create a systemd service for the blockchain node
- use `Restart=always`
- set sane restart delay

### Option B: watchdog script

- process monitor script checks whether the node is alive
- if unhealthy, restart the node
- log restart events to file

Tasks:

- create `scripts/restart_node.sh`
- log:
  - timestamp
  - reason
  - action taken

Success criteria:

- killing the node leads to automatic recovery
- recovery event is documented in logs

## 8. 16:15-17:15 Failure Drills

Run controlled failure scenarios.

Required drills:

1. kill the node process
2. break RPC health by stopping the node
3. generate CPU stress
4. simulate disk pressure if safe

For each drill, capture:

- what failed
- how it was detected
- which alert fired
- whether recovery worked
- time to recover

Success criteria:

- screenshots or logs for each drill
- at least one successful alert and one successful restart

## 9. 17:15-18:30 Documentation

Write the following:

### `README.md`

Include:

- project overview
- architecture
- setup instructions
- how to run services
- how to test alerts
- dashboard overview

### `docs/RUNBOOK.md`

Include:

- common failure modes
- how to verify service health
- how to restart the node
- where logs and metrics live
- what each alert means

### `docs/INCIDENT.md`

Write one short postmortem for a simulated incident:

- summary
- impact
- timeline
- root cause
- detection
- recovery
- preventive action

Success criteria:

- someone else can run the project from docs alone

## 10. 18:30-20:00 Polish and Submission Prep

Finalize the project for presentation.

Tasks:

- clean configs
- verify commands
- capture dashboard screenshots
- capture alert screenshots
- make file names clear
- ensure README explains why this is relevant to blockchain SRE

Prepare a short pitch:

> Built a blockchain node reliability lab that simulates production SRE workflows for blockchain infrastructure, including monitoring, alerting, auto-recovery, and incident documentation under constrained resources.

## Technical Decisions

### Why local dev node instead of a public full node

- cheaper
- faster to set up in one day
- still demonstrates SRE skills
- easier to simulate failure and recovery

### Why this maps to the job

This project demonstrates:

- Linux operations
- reliability thinking
- monitoring and observability
- troubleshooting
- scripting and automation
- documentation quality
- incident response workflow

## Risks and Mitigations

### Risk: Prometheus and Grafana setup takes too long

Mitigation:

- use Docker Compose
- begin with minimal default configs
- skip advanced dashboards until core metrics work

### Risk: Alert notifications take too long

Mitigation:

- accept Alertmanager UI proof instead of full email integration
- use a simple webhook if email setup becomes a blocker

### Risk: custom exporter is too slow to implement

Mitigation:

- use a simple polling script and output a textfile metric
- keep only `rpc_up` and `rpc_response_seconds`

### Risk: time runs short

Mitigation:

- prioritize monitoring, alerts, and restart automation
- reduce scope on UI polish and advanced incident simulations

## Must-Have Checklist

- [ ] blockchain node runs locally
- [ ] host metrics collected
- [ ] RPC health metrics collected
- [ ] Prometheus target health is green
- [ ] Grafana dashboard displays data
- [ ] at least 3 working alerts
- [ ] node auto-restart demonstrated
- [ ] one simulated incident documented
- [ ] README written

## Nice-to-Have Checklist

- [ ] Alertmanager sends real notifications
- [ ] dashboard looks polished
- [ ] screenshots included
- [ ] multiple failure drills documented
- [ ] latency graph added
- [ ] restart count metric added

## Expected Demo Flow

If you need to present this quickly, use this order:

1. explain architecture in 30 seconds
2. show blockchain node running
3. show Grafana dashboard
4. kill the node process
5. show alert firing
6. show auto-restart
7. show recovery in dashboard and logs
8. close with runbook and postmortem

## Resume/GitHub Positioning

Possible project title:

`Blockchain Node Reliability Lab`

Possible one-line description:

`Built a lightweight blockchain SRE lab with node monitoring, Prometheus/Grafana observability, alerting, and automated recovery for simulated node failures.`

## If You Finish Early

Add one of these:

- Dockerize the whole stack
- expose a small `/metrics` endpoint from Python
- add restart counters
- add a second fake node target
- create a simple architecture diagram image
- add structured JSON logs for incidents

## Bottom Line

The winning version of this project is not the biggest one. It is the version that clearly proves:

- you can run services
- you can observe them
- you can detect failure
- you can recover them
- you can document what happened
