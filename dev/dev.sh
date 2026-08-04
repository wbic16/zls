#!/usr/bin/env bash
set -euo pipefail

# Simple dev bootstrap to launch a 5-zone QEMU topology using a base qcow2 image.
# Designed for Linux or WSL2. Uses user-mode networking with SSH port forwarding.

BASE_IMG=${BASE_IMG:-./images/ubuntu-2025.qcow2}
VM_DIR=${VM_DIR:-./dev/vms}
SSH_BASE_PORT=${SSH_BASE_PORT:-2222}
MEM=${MEM:-8192}
SMP=${SMP:-2}
NUM=${NUM:-5}

mkdir -p "$VM_DIR"

if [ ! -f "$BASE_IMG" ]; then
  echo "Base image $BASE_IMG not found. Place an Ubuntu QCOW2 at that path or set BASE_IMG."
  exit 1
fi

for i in $(seq 1 $NUM); do
  vm=vm$i
  img="$VM_DIR/$vm.qcow2"
  if [ ! -f "$img" ]; then
    echo "Creating backing copy for $vm"
    qemu-img create -f qcow2 -b "$BASE_IMG" "$img"
  fi
  ssh_port=$((SSH_BASE_PORT + i - 1))
  pidsfile="$VM_DIR/$vm.pid"
  echo "Starting $vm -> ssh: $ssh_port"
  qemu-system-x86_64 \
    -enable-kvm \
    -m "$MEM" \
    -smp "$SMP" \
    -drive file="$img",if=virtio \
    -netdev user,id=net$i,hostfwd=tcp::${ssh_port}-:22 \
    -device virtio-net-pci,netdev=net$i \
    -nographic \
    -daemonize \
    -pidfile "$pidsfile" \
    || echo "qemu failed for $vm"
done

echo "Launched $NUM VMs (usernet, SSH forwarded)."
echo "SSH ports:"
for i in $(seq 1 $NUM); do
  port=$((SSH_BASE_PORT + i - 1))
  echo "  zone$i -> localhost:$port"
done
