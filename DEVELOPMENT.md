Development environment and bootstrap for ZLS

Overview
--------
This document describes the baseline developer environment for the ZLS MVP. The scripts assume a Linux environment (native or WSL2 on Windows). We use QEMU for a reproducible 5-zone topology and Docker/Podman for containerized service development.

Quick start
-----------
- Put a base QCOW2 image (Ubuntu 2025 LTS) at `./images/ubuntu-2025.qcow2`.
- Start the local topology:

```bash
make start
```

- SSH into the zones on ports `2222`..`2226` (zone1 -> 2222).

Files added
-----------
- `dev/dev.sh` — boots 5 QEMU instances using a base image and user-mode networking.
- `dev/qemu_topology.sh` — helper wrapper to inspect and manage the topology.
- `Makefile` — convenience targets: `start`, `stop`, `clean`.
- `.github/workflows/ci.yml` — CI skeleton (lint/test matrix).

Notes
-----
- KVM acceleration is used when available. On Windows, run these scripts from WSL2 for best results.
- The scripts intentionally use user-networking and SSH port forwarding to avoid requiring host network setup.

Next steps
----------
- Provide or build the `./images/ubuntu-2025.qcow2` base image (I can add a `cloud-init` iso generator and an image build script next).
- Add a sample HiOS user-space service and an IPC example.
