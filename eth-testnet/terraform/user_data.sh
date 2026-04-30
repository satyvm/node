#!/bin/bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
sleep 20

# ---------------------------------------------------------------------------
# Identify the data disk safely.
#
# Strategy: find the root device by inspecting what is mounted at /, then
# find the first disk that (a) is NOT the root device and (b) has no
# filesystem yet (FSTYPE is empty → genuinely unformatted).
#
# This is safe regardless of volume size, attachment order, or root volume
# size changes. It will never accidentally format a disk that already has
# a filesystem.
# ---------------------------------------------------------------------------
ROOT_DISK=$(lsblk -ndo PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)
# Fallback: if PKNAME is empty (no parent, e.g. device is itself a disk)
if [ -z "$ROOT_DISK" ]; then
    ROOT_DISK=$(basename "$(findmnt -n -o SOURCE /)" | sed 's/p[0-9]*$//' | sed 's/[0-9]*$//')
fi

DATA_VOL=$(lsblk -dpno NAME,FSTYPE | awk \
  -v root="/dev/$ROOT_DISK" \
  '$1 != root && $2 == "" && $1 !~ /loop/ { print $1; exit }')

if [ -n "$DATA_VOL" ]; then
    mkfs -t ext4 "$DATA_VOL"
    mkdir -p /mnt/ethereum
    mount "$DATA_VOL" /mnt/ethereum

    # Add to fstab for persistence across reboots
    UUID=$(blkid -s UUID -o value "$DATA_VOL")
    echo "UUID=$UUID /mnt/ethereum ext4 defaults,nofail 0 2" >> /etc/fstab

    mkdir -p /mnt/ethereum/nethermind
    mkdir -p /mnt/ethereum/lighthouse
    mkdir -p /mnt/ethereum/grafana-data
    chown -R ubuntu:ubuntu /mnt/ethereum
else
    echo "ERROR: Could not find an unformatted data volume. Aborting disk setup." >&2
fi
