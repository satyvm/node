#!/bin/bash
set -euo pipefail

BASE_DIR="/mnt/ethereum/ephemery"
DATA_DIR="/mnt/ethereum/data"
TMP_DIR=$(mktemp -d)
ARCHIVE_PATH="$TMP_DIR/testnet-all.tar.gz"
EXTRACT_DIR="$TMP_DIR/extracted"
HASH_FILE="$BASE_DIR/release.sha256"
BUNDLE_URL="https://github.com/ephemery-testnet/ephemery-genesis/releases/latest/download/testnet-all.tar.gz"
STATE_VERSION="2"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$EXTRACT_DIR" "$DATA_DIR"

echo "Downloading latest Ephemery network bundle..."
curl -fsSL "$BUNDLE_URL" -o "$ARCHIVE_PATH"
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

for required_file in config.yaml genesis.ssz genesis.json chainspec.json nodevars_env.txt deposit_contract_block.txt; do
    if [ ! -f "$EXTRACT_DIR/$required_file" ]; then
        echo "ERROR: Missing $required_file in Ephemery bundle." >&2
        exit 1
    fi
done

NEW_HASH=$(
    {
        sha256sum "$ARCHIVE_PATH" | awk '{print $1}'
        printf '%s\n' "$STATE_VERSION"
    } | sha256sum | awk '{print $1}'
)
CURRENT_HASH=""
if [ -f "$HASH_FILE" ]; then
    CURRENT_HASH=$(cat "$HASH_FILE")
fi

if [ "$NEW_HASH" != "$CURRENT_HASH" ]; then
    echo "Ephemery network bundle changed; resetting client data for the new iteration."
    if [ -f /mnt/ethereum/docker-compose.yml ]; then
        cd /mnt/ethereum
        docker compose --env-file ./ephemery/nodevars_env.txt down || true
    fi
    sudo rm -rf "$DATA_DIR/nethermind" "$DATA_DIR/lighthouse"
    mkdir -p "$DATA_DIR/nethermind" "$DATA_DIR/lighthouse"
    sudo chown -R ubuntu:ubuntu "$DATA_DIR"
fi

rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"
cp -a "$EXTRACT_DIR"/. "$BASE_DIR"/

BOOTNODES=""
if [ -f "$BASE_DIR/bootnode.txt" ]; then
    BOOTNODES=$(paste -sd, "$BASE_DIR/bootnode.txt" | tr -d '\r')
else
    BOOTNODES=$(awk -F= '/^BOOTNODE_ENODE=/{print $2}' "$BASE_DIR/nodevars_env.txt" | tr -d '\r')
fi

if [ -z "$BOOTNODES" ]; then
    echo "ERROR: Could not derive Nethermind bootnodes from Ephemery bundle." >&2
    exit 1
fi

TMP_ENV=$(mktemp)
awk '!/^NETHERMIND_BOOTNODES=/' "$BASE_DIR/nodevars_env.txt" > "$TMP_ENV"
printf 'NETHERMIND_BOOTNODES=%s\n' "$BOOTNODES" >> "$TMP_ENV"
mv "$TMP_ENV" "$BASE_DIR/nodevars_env.txt"

printf '%s\n' "$NEW_HASH" > "$HASH_FILE"

echo "Ephemery network bundle ready."
