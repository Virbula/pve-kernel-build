# Proxmox VE Kernel Packages

This document describes the **Debian packages produced by a Proxmox VE kernel build**, what each package contains, and when it is typically used. The content is **generic to all kernel versions** and intentionally avoids hard-coding specific version numbers.

---

## Overview

A Proxmox kernel build follows standard Debian kernel packaging conventions, with additional **Proxmox-specific meta and signing packages**. The output is intentionally split into multiple packages to support:

- Clean upgrades and rollbacks
- DKMS / ZFS compatibility
- Secure Boot workflows
- Developer and debugging use cases

---

## Kernel Packages (Boot-Critical)

### `proxmox-kernel-<VERSION>-pve_<VERSION>_amd64.deb`
**The actual Proxmox kernel package**

Contains:
- `vmlinuz-<VERSION>-pve`
- `System.map-<VERSION>-pve`
- Kernel modules under `/lib/modules/<VERSION>-pve/`

Usage:
- Installed on every Proxmox VE node
- This is the kernel that the system boots

> If only one package is installed, this is the one.

---

## Kernel Header Packages (DKMS / ZFS / Drivers)

### `proxmox-headers-<VERSION>-pve_<VERSION>_amd64.deb`
**Architecture-specific kernel headers**

Used for:
- ZFS kernel modules
- NVIDIA / GPU drivers
- Any DKMS-based module

Must exactly match the running kernel version.

---

### `proxmox-headers-<MAJOR>.<MINOR>_<VERSION>_all.deb`
**Meta header package**

- Architecture-independent (`all`)
- Depends on `proxmox-headers-<VERSION>-pve`
- Allows software to depend generically on “kernel `<MAJOR>.<MINOR>` headers”

> This package contains no headers itself; it is dependency glue.

---

## Kernel Tools (Optional)

### `linux-tools-<MAJOR>.<MINOR>_<VERSION>_amd64.deb`
**Kernel performance and tracing tools**

Provides:
- `perf`
- `turbostat`
- Scheduler and CPU profiling utilities

Primarily for:
- Debugging
- Performance analysis
- Development systems

---

### `linux-tools-<MAJOR>.<MINOR>-dbgsym_<VERSION>_amd64.deb`
**Debug symbols for linux-tools**

- Required only when debugging kernel tools themselves
- Not needed for normal operation

---

## Userspace / ABI Development

### `proxmox-kernel-libc-dev_<VERSION>_amd64.deb`
**Userspace kernel headers for libc and low-level tooling**

Used by:
- `glibc`
- Low-level system utilities

Ensures ABI consistency between kernel and userspace during development.

---

## Proxmox-Specific Meta and Signing Packages

### `proxmox-kernel-<MAJOR>.<MINOR>_<VERSION>_all.deb`
**Kernel meta package**

- Contains no kernel payload
- Depends on `proxmox-kernel-<VERSION>-pve`
- Used by Proxmox repositories to track the active kernel series

Enables:
- Safe upgrades
- Multiple kernels installed side-by-side
- Predictable dependency resolution

---

### `proxmox-kernel-<VERSION>-pve-signed-template_<VERSION>_amd64.deb`
**Secure Boot signing template**

- Used by Proxmox’s kernel signing infrastructure
- Relevant only when Secure Boot is enabled
- Normally not installed manually

---

## Package Relationship Diagram

```
Meta kernel package
└─ proxmox-kernel-<MAJOR>.<MINOR> (all)
   └─ proxmox-kernel-<VERSION>-pve (actual kernel)

Headers
├─ proxmox-headers-<MAJOR>.<MINOR> (all)
└─ proxmox-headers-<VERSION>-pve (amd64)

Tools
├─ linux-tools-<MAJOR>.<MINOR>
└─ linux-tools-<MAJOR>.<MINOR>-dbgsym

Development / ABI
└─ proxmox-kernel-libc-dev
```

---

## Typical Installation Scenarios

### Minimal Proxmox VE Node
```bash
proxmox-kernel-<VERSION>-pve
```

### Standard Proxmox VE Node
```bash
proxmox-kernel-<MAJOR>.<MINOR>
proxmox-headers-<MAJOR>.<MINOR>
```

### Developer / DKMS / ZFS System
```bash
proxmox-headers-<VERSION>-pve
proxmox-kernel-libc-dev
```

---

## Design Rationale

Proxmox follows Debian best practices by:
- Separating **payload** (kernel) from **policy** (meta packages)
- Allowing **multiple kernels** to coexist
- Supporting **safe rollback** via bootloader selection
- Keeping **DKMS and ZFS stable across upgrades**

This design is intentional and critical for enterprise-grade virtualization platforms.

---

## Notes

- Only the `*-pve` kernel package is booted
- Meta packages exist for dependency management and upgrades
- Most systems do not need debug or signing packages

---

_End of document_
