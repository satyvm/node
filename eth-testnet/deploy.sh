#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

MODE="full"

if [ "${1:-}" = "--sync-only" ]; then
    MODE="sync-only"
elif [ $# -gt 0 ]; then
    echo "Usage: $0 [--sync-only]"
    exit 1
fi

echo "Ethereum Node Deployment Script"
echo "Mode: $MODE"

# ── Step 1: Load Configuration ──────────────────────────────────────────────
# Source .env for SSH_KEY, DISCORD_WEBHOOK_URL, and other secrets.
# Falls back to the default key path if SSH_KEY is not set.

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

SSH_KEY="${SSH_KEY:-~/.ssh/satyvm-aws.pem}"

echo "🔑 SSH key: $SSH_KEY"

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    echo "❌ DISCORD_WEBHOOK_URL is not set."
    echo "   → Copy .env.example to .env and fill in your Discord webhook URL."
    exit 1
fi

# ── Step 2: Resolve EC2 IP ──────────────────────────────────────────────────
# Pull the instance IP from Terraform state. This requires a prior
# 'terraform apply' to have succeeded.

echo ""
echo "[1/7] Fetching EC2 IP from Terraform..."
cd terraform
IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
cd ..

if [ -z "$IP" ] || [[ "$IP" == *"No outputs"* ]]; then
    echo "❌ Could not retrieve IP. Did you run 'terraform apply'?"
    exit 1
fi

echo "  ✅ Target: $IP"

# ── Step 3: Wait for SSH ────────────────────────────────────────────────────
# The EC2 instance may still be booting. Retry SSH for up to 2 minutes.

echo ""
echo "[2/7] Waiting for SSH..."
MAX_RETRIES=24    # 24 × 5s = 120s
RETRY=0
until ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i "$SSH_KEY" ubuntu@"$IP" 'echo ok' &>/dev/null; do
    RETRY=$((RETRY + 1))
    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        echo "❌ SSH not available after 120s. Check Security Group and key pair."
        exit 1
    fi
    echo "  Retrying in 5s ($RETRY/$MAX_RETRIES)..."
    sleep 5
done
echo "  ✅ SSH is ready."

# ── Step 4: Wait for cloud-init ─────────────────────────────────────────────
# cloud-init runs user_data.sh (installs Docker, formats/mounts EBS disk).
# We must wait for it to finish before deploying anything.

echo ""
echo "[3/7] Waiting for cloud-init to finish..."
ssh -i "$SSH_KEY" ubuntu@"$IP" 'cloud-init status --wait'
echo "  ✅ cloud-init complete."

# ── Step 5: Generate JWT secret (once) ──────────────────────────────────────
# The JWT secret authenticates the Engine API link between Nethermind and
# Lighthouse. Generate it only if it doesn't already exist on the server.

echo ""
echo "[4/7] Ensuring JWT secret exists..."
ssh -i "$SSH_KEY" ubuntu@"$IP" '
  if [ ! -s /mnt/ethereum/jwtsecret ]; then
    openssl rand -hex 32 | tr -d "\n" > /mnt/ethereum/jwtsecret
    echo "  ✅ New JWT secret generated."
  else
    echo "  ✅ JWT secret already exists — skipping."
  fi
'

# ── Step 6: Sync config files ───────────────────────────────────────────────
# rsync the repo to /mnt/ethereum on the server.
# Excludes: terraform (not needed), .git, data dirs, secrets, deploy script,
# and the alertmanager template (rendered separately with envsubst below).

echo ""
echo "[5/7] Syncing configuration files..."
rsync -avz \
  --exclude 'terraform' \
  --exclude '.git' \
  --exclude 'data' \
  --exclude 'jwtsecret' \
  --exclude 'deploy.sh' \
  --exclude 'alertmanager/alertmanager.yml' \
  -e "ssh -i $SSH_KEY" \
  ./ ubuntu@"$IP":/mnt/ethereum/

# Render the Alertmanager config, replacing ${DISCORD_WEBHOOK_URL} with
# the real secret from .env, then upload the rendered file.
echo "Injecting Discord webhook into Alertmanager config..."
# shellcheck disable=SC2016
envsubst '${DISCORD_WEBHOOK_URL}' < alertmanager/alertmanager.yml > /tmp/alertmanager_rendered.yml
scp -i "$SSH_KEY" /tmp/alertmanager_rendered.yml ubuntu@"$IP":/mnt/ethereum/alertmanager/alertmanager.yml
rm /tmp/alertmanager_rendered.yml

echo "✅ Config synced."

if [ "$MODE" = "full" ]; then
    echo ""
    echo "[6/7] Preparing Ephemery network files..."
    ssh -i "$SSH_KEY" ubuntu@"$IP" 'cd /mnt/ethereum && bash ./prepare_ephemery.sh'
else
    echo ""
    echo "[6/7] Skipping Ephemery bundle refresh (--sync-only)."
fi

# ── Step 7: Start containers ────────────────────────────────────────────────

if [ "$MODE" = "full" ]; then
    echo ""
    echo "[7/7] Starting Docker containers..."
    ssh -i "$SSH_KEY" ubuntu@"$IP" 'cd /mnt/ethereum && docker compose --env-file ./ephemery/nodevars_env.txt up -d'
else
    echo ""
    echo "[7/7] Skipping container restart (--sync-only)."
fi

# ── Done ────────────────────────────────────────────────────────────────────
echo "Deployment Complete!"
