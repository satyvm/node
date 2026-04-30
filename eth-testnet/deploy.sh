#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "=========================================="
echo "🚀 Ethereum Node Deployment Script"
echo "=========================================="

if [ -f ".env" ]; then
    set -a; source .env; set +a
fi
SSH_KEY="${SSH_KEY:-~/.ssh/satyvm-aws.pem}"
echo "🔑 Using SSH key: $SSH_KEY"
if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    echo "❌ Error: DISCORD_WEBHOOK_URL is not set."
    echo "   Copy .env.example to .env and fill in your Discord webhook URL."
    exit 1
fi

echo "Fetching EC2 IP address from Terraform..."
cd terraform
IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
cd ..

if [ -z "$IP" ] || [[ "$IP" == *"No outputs"* ]]; then
    echo "❌ Error: Could not retrieve IP address. Did you run 'terraform apply'?"
    exit 1
fi

echo "✅ Target Server IP: $IP"

echo "⏳ Waiting for SSH to become available..."
MAX_RETRIES=24    # 24 x 5s = 120 seconds max wait
RETRY=0
until ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i ~/.ssh/satyvm-aws.pem ubuntu@$IP 'echo ok' &>/dev/null; do
    RETRY=$((RETRY + 1))
    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        echo "❌ Error: SSH not available after 120 seconds. Check your Security Group and key pair."
        exit 1
    fi
    echo "   SSH not ready yet... retrying in 5s ($RETRY/$MAX_RETRIES)"
    sleep 5
done
echo "✅ SSH is ready!"

echo "⏳ Waiting for cloud-init to finish (disk formatting, Docker install)..."
ssh -i ~/.ssh/satyvm-aws.pem ubuntu@$IP 'cloud-init status --wait'

echo "🔑 Ensuring JWT secret exists on the server (generated once, never overwritten)..."
ssh -i ~/.ssh/satyvm-aws.pem ubuntu@$IP '
  if [ ! -s /mnt/ethereum/jwtsecret ]; then
    openssl rand -hex 32 | tr -d "\n" > /mnt/ethereum/jwtsecret
    echo "  ✅ New JWT secret generated."
  else
    echo "  ✅ JWT secret already exists, skipping."
  fi
'

echo "📁 Syncing configuration files to /mnt/ethereum..."
# We exclude the template so we don't overwrite the rendered version on the server
rsync -avz \
  --exclude 'terraform' \
  --exclude '.git' \
  --exclude 'data' \
  --exclude 'jwtsecret' \
  --exclude 'deploy.sh' \
  --exclude 'alertmanager/alertmanager.yml' \
  -e "ssh -i ~/.ssh/satyvm-aws.pem" \
  ./ ubuntu@$IP:/mnt/ethereum/

echo "🔔 Injecting Discord Webhook into Alertmanager config..."
# We use envsubst to swap the ${VARIABLE} for the real secret from your .env
envsubst '${DISCORD_WEBHOOK_URL}' < alertmanager/alertmanager.yml > /tmp/alertmanager_rendered.yml
scp -i ~/.ssh/satyvm-aws.pem /tmp/alertmanager_rendered.yml ubuntu@$IP:/mnt/ethereum/alertmanager/alertmanager.yml
rm /tmp/alertmanager_rendered.yml

echo "🐳 Starting Docker Containers..."
ssh -i ~/.ssh/satyvm-aws.pem ubuntu@$IP 'cd /mnt/ethereum && docker compose up -d'

echo "=========================================="
echo "🎉 Deployment Complete!"
echo "Your Ethereum node is spinning up in the background."
echo ""
echo "To view Nethermind logs:"
echo "  ssh -i ~/.ssh/satyvm-aws.pem ubuntu@$IP 'sudo docker logs -f nethermind'"
echo ""
echo "To view Lighthouse logs:"
echo "  ssh -i ~/.ssh/satyvm-aws.pem ubuntu@$IP 'sudo docker logs -f lighthouse'"
echo "=========================================="
