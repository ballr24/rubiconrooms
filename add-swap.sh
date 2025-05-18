#!/usr/bin/env bash
set -euo pipefail

# must be root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

SWAPFILE=/swapfile

# Prompt for swap size
read -rp "Enter swap file size (e.g. 1G, 512M): " SIZE
# fallback to 1G if empty
SIZE=${SIZE:-1G}

echo "→ Creating ${SIZE} swapfile at ${SWAPFILE}…"
if ! fallocate -l "${SIZE}" "${SWAPFILE}" 2>/dev/null; then
  # compute count if SIZE ends with G or M
  if [[ $SIZE =~ ^([0-9]+)G$ ]]; then
    COUNT=$((BASH_REMATCH[1] * 1024))
  elif [[ $SIZE =~ ^([0-9]+)M$ ]]; then
    COUNT=${BASH_REMATCH[1]}
  else
    echo "Invalid size format. Use e.g. 1G or 512M." >&2
    exit 1
  fi
  dd if=/dev/zero of="${SWAPFILE}" bs=1M count="${COUNT}" status=progress
fi

echo "→ Securing permissions…"
chmod 600 "${SWAPFILE}"

echo "→ Formatting as swap…"
mkswap "${SWAPFILE}"

echo "→ Enabling swap…"
swapon "${SWAPFILE}"

echo "→ Adding to /etc/fstab…"
grep -qF "${SWAPFILE}" /etc/fstab || \
  echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab

echo "→ Tuning swappiness to 10…"
sysctl vm.swappiness=10
grep -qF 'vm.swappiness' /etc/sysctl.conf || \
  echo 'vm.swappiness=10' >> /etc/sysctl.conf

echo
echo "✅ Swap + swappiness setup complete!"
echo

# --- Confirmation output ---
echo "Current swap configuration:"
swapon --show

echo
echo -n "Current vm.swappiness: "
cat /proc/sys/vm/swappiness
