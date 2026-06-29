# ⛓️ Blockchain SRE & Infrastructure Lab

This repository is a comprehensive laboratory for Blockchain Site Reliability Engineering (SRE) and Infrastructure. It contains two main projects designed to take you from local simulations to production-grade cloud deployments.

## 🚀 Projects

### 1. [Anvil SRE Simulation](./anvil)

A fully containerized laboratory for practicing SRE fundamentals using a local Ethereum-compatible node (`anvil`).

- **Focus:** Automation, Measurement, Visualization, and Incident Response.
- **Tech Stack:** Docker Compose, Prometheus, Grafana, Alertmanager, Anvil.
- **Key Features:** Pre-provisioned dashboards, simulated failure scenarios (node crashes, high CPU), and a custom RPC health checker.

### 2. [Ethereum Testnet (Ephemery) Deployment](./eth-testnet)

A production-ready infrastructure-as-code setup for deploying a full Ethereum node on AWS.

- **Focus:** Scalability, Reliability, and Ephemeral Network management.
- **Tech Stack:** Terraform, AWS (EC2/EBS), Docker, Nethermind (Execution), Lighthouse (Consensus), Prometheus, Grafana, Tempo.
- **Key Features:** Automated Ephemery network resets, SSH tunneling for secure monitoring, checkpoint sync for rapid startup, and distributed tracing.

---

## 🛠️ Core SRE Principles Demonstrated

- **Infrastructure as Code (IaC):** Using Terraform for reproducible AWS environments.
- **Observability:** Full-stack monitoring with Prometheus, Grafana, and Tempo.
- **Automated Operations:** Makefile-driven workflows for deployment and management.
- **Resilience:** Health checks, restart policies, and chaos engineering experiments.
- **Security:** Secure RPC handling, JWT authentication between clients, and firewall configurations.

---

## 📂 Repository Structure

```bash
.
├── anvil/           # Local SRE simulation environment
└── eth-testnet/     # Production-ready AWS deployment for Ephemery
```

---

## 🏁 Getting Started

Depending on your goal, navigate to one of the project subdirectories:

- To learn SRE basics in a safe, local environment: **[Go to Anvil Lab](./anvil)**
- To deploy a real Ethereum node to the cloud: **[Go to Ethereum Testnet](./eth-testnet)**
