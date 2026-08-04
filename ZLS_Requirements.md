# Zero Latency System

Welcome, to the Zero Latency System. This project has one goal: the user *never* has to wait for the system to respond. Work can be pending, but never blocked or stalled. ZLS is a modern take on systems development, and provides the scaffolding required for the Exocortex of 2130.

## Pre-requisites

- PREEMPT_RT kernel
- 1 TB unused disk space
- 8 cores
- 32 GB DDR5 RAM

## Targets

- Live upgrade from an existing distro (Ubuntu LTS) or Windows - zero technical knowledge required to get started
- Five zone virtual machine (host, admin-a, admin-b, user-a, user-b) - updates *never* interfere with the user experience
- All human I/O managed by non-blocking services
- target 4K cycles response time for events
- target 4M cycles for human I/O
- cooperative kernels with message passing between cores

## Subsystems

- Kernel: one kernel per core (eliminate context switching)
- HiOS: Human Input/Output Subsystem - "Hi, OS!"
- Batch: Maximum throughput for processing - no GUI interaction
- Messaging: Inter-system and inter-process communication layer
- Phext-Aware Filesystem: Automatic sharding across systems
- Builder: Constructs new environments and tears down unused ones
- Deployer: Controls runtime deployments for operating environments
- Hypernaut: Validates environment shifts so the user isn't bothered needlessly

## Deliverables

- userspace mvp
- bootable USB drive
- baseline distros (alpine, ubuntu, buildroot)
- development environment
- agentic integration
- messaging subsystem
- hios environment
- podman container swaps

## Roadmap

Every week, we chart the next few weeks here and finalize history / delivered items.

- 8/25: mvp deployment
- 8/18: HiOS proof of concept
- 8/11: 5-zone system prototype
- 8/4: finalize scope, create dev environment

## Technology

- qemu/kvm
- ipc using shared memory and pre-allocated buffers
- 