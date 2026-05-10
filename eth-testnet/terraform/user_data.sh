#!/bin/bash
set -euo pipefail
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
# Wait for Docker daemon to be fully ready (socket accepting commands)
for i in $(seq 1 30); do
    docker info >/dev/null 2>&1 && break
    echo "Waiting for Docker daemon... ($i/30)"
    sleep 2
done
docker info >/dev/null 2>&1 || { echo "ERROR: Docker daemon failed to start." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Identify the data disk safely.
#
# Strategy: find the root device by inspecting what is mounted at /, then
# find the first disk that is NOT the root device, then format it only
# if it does not already have a filesystem.
#
# This is safe regardless of volume size, attachment order, or root volume
# size changes. It works for both brand-new volumes and previously
# formatted volumes restored from snapshots or reattached from older nodes.
# ---------------------------------------------------------------------------
ROOT_DISK=$(lsblk -ndo PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)
# Fallback: if PKNAME is empty (no parent, e.g. device is itself a disk)
if [ -z "$ROOT_DISK" ]; then
    ROOT_DISK=$(basename "$(findmnt -n -o SOURCE /)" | sed 's/p[0-9]*$//' | sed 's/[0-9]*$//')
fi

DATA_VOL=""
for i in $(seq 1 180); do
    DATA_VOL=$(lsblk -dpno NAME,TYPE | awk \
      -v root="/dev/$ROOT_DISK" \
      '$2 == "disk" && $1 != root && $1 !~ /loop/ { print $1; exit }')
    if [ -n "$DATA_VOL" ]; then
        break
    fi
    echo "Waiting for data volume... ($i/180)"
    sleep 2
done

if [ -z "$DATA_VOL" ]; then
    echo "ERROR: Could not find an attached data volume. Aborting disk setup." >&2
    exit 1
fi

FS_TYPE=$(lsblk -no FSTYPE "$DATA_VOL" | head -n 1 | tr -d '[:space:]')

if [ -z "$FS_TYPE" ]; then
    mkfs -t ext4 "$DATA_VOL"
fi

install -d -o ubuntu -g ubuntu /mnt/ethereum

# Add to fstab for persistence across reboots
UUID=$(blkid -s UUID -o value "$DATA_VOL")
if ! grep -q "^UUID=$UUID /mnt/ethereum " /etc/fstab; then
    echo "UUID=$UUID /mnt/ethereum ext4 defaults,nofail 0 2" >> /etc/fstab
fi

mountpoint -q /mnt/ethereum || mount /mnt/ethereum
chown ubuntu:ubuntu /mnt/ethereum
