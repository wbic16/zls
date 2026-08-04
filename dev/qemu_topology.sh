#!/usr/bin/env bash
set -euo pipefail

VM_DIR=${VM_DIR:-./dev/vms}

if [ ! -d "$VM_DIR" ]; then
  echo "VM directory not found: $VM_DIR"
  exit 1
fi

echo "Listing running topology (pid files in $VM_DIR):"
for pidfile in "$VM_DIR"/*.pid; do
  [ -e "$pidfile" ] || continue
  vm=$(basename "$pidfile" .pid)
  pid=$(cat "$pidfile" 2>/dev/null || echo "?")
  echo "$vm -> pid=$pid"
done

echo
echo "SSH ports (assumes default BASE SSH 2222):"
port=2222
for i in 1 2 3 4 5; do
  echo "  zone$i -> localhost:$port"
  port=$((port+1))
done
