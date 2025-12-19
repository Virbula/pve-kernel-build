# Proxmox Kernel Signing and Secure Boot

This document explains **how Proxmox VE integrates Secure Boot**, and how you can **create a signed custom kernel** suitable for Secure Boot systems.

It focuses on practical, reproducible steps and highlights the two common trust models:

- **MOK (Machine Owner Key) / shim**: easiest for custom kernels in controlled environments.
- **Microsoft-signed shim**: for wide distribution without asking users to enroll keys (much heavier process).

> Proxmox VE supports Secure Boot via signed packages and boot tooling integration (notably with `proxmox-boot-tool`) on modern releases. citeturn0search16

---

## Concepts and moving parts

### What must be signed
With UEFI Secure Boot enabled, the platform typically requires a trusted signature chain for:

1. **shim** (often Microsoft-signed)
2. **bootloader** (GRUB or systemd-boot EFI binary)
3. **kernel image** (`vmlinuz*`)

In addition, once the kernel is running, it can enforce signatures for **kernel modules** (this matters for DKMS modules like ZFS or NVIDIA). Proxmox documentation notes that additional modules must be signed with a key trusted by the Secure Boot stack. citeturn0search12

### The two practical trust models

#### Model A: MOK (recommended for custom kernels you distribute to admins)
- You generate your own keypair.
- You sign kernels (and modules) with that key.
- Users enroll your public key into MOK once (via `mokutil`).

This aligns with the “shim + MOK” approach described in Proxmox discussions/docs. citeturn0search4turn0search0

#### Model B: Microsoft-signed shim (recommended only for an OS/appliance vendor)
- You submit **your shim** through the shim review process and Microsoft UEFI CA signing pipeline.
- Firmware trusts your shim out-of-the-box (because it’s signed by Microsoft UEFI CA).
- Your shim trusts your vendor key; you sign everything else with that key.

The shim review process and Microsoft submission requirements are documented publicly. citeturn0search2turn0search6

---

## Prerequisites

### Packages/tools you will typically need (Debian/Proxmox host or build machine)
- `sbsigntool` (provides `sbsign`, `sbverify`)
- `mokutil` (MOK enrollment/status)
- `openssl` (key generation)
- Kernel build tree (your custom Proxmox kernel build output)

Install (example):
```bash
apt-get update
apt-get install -y sbsigntool mokutil openssl
```

---

## Step 1 — Generate your signing key (MOK keypair)

Create a long-lived RSA keypair (example 10 years). Keep the private key secure.

```bash
openssl req -new -x509 -newkey rsa:4096   -keyout MOK.priv   -out MOK.pem   -nodes   -days 3650   -subj "/CN=Custom Proxmox Kernel MOK/"
```

Convert the certificate to DER format (commonly used for enrollment):
```bash
openssl x509 -in MOK.pem -outform DER -out MOK.der
```

---

## Step 2 — Enroll your public key into MOK (one-time per machine)

On the target machine (the Proxmox host that will boot the custom kernel):

```bash
mokutil --import MOK.der
reboot
```

During reboot, **MokManager** will appear. Choose:
- Enroll MOK
- Confirm
- Enter the password you set in `mokutil`

Verify after boot:
```bash
mokutil --sb-state
mokutil --list-enrolled | less
```

---

## Step 3 — Sign the kernel image

### Find the kernel image you are going to ship
For Debian/Proxmox kernel packages, the installed kernel typically lives under `/boot` as `vmlinuz-<KVER>`.

If you’re signing *before packaging*, you’ll sign the `vmlinuz` produced by your build.

### Sign with `sbsign`
```bash
sbsign   --key MOK.priv   --cert MOK.pem   --output vmlinuz-<KVER>.signed   vmlinuz-<KVER>
```

Verify the signature:
```bash
sbverify --list vmlinuz-<KVER>.signed
```

> Tip: keep the unsigned kernel too; it’s useful for troubleshooting on non–Secure Boot systems.

---

## Step 4 — Sign kernel modules (DKMS and out-of-tree modules)

If Secure Boot module validation is active, **unsigned modules may fail to load**. Proxmox notes DKMS modules need signing and references the default DKMS MOK key location and enrollment flow. citeturn0search4

### Option A: Let DKMS sign modules (preferred)
Proxmox/DKMS commonly uses a keypair under `/var/lib/dkms/`.

If you want to trust the DKMS-generated key:
```bash
mokutil --import /var/lib/dkms/mok.pub
reboot
```

### Option B: Sign a specific module yourself
Use the kernel build helper `scripts/sign-file` (path may vary; commonly found in kernel headers sources):

```bash
/usr/src/linux-headers-<KVER>/scripts/sign-file sha256   MOK.priv MOK.der   /lib/modules/<KVER>/extra/<module>.ko
```

Confirm module signature info (often visible via `modinfo`):
```bash
modinfo /lib/modules/<KVER>/extra/<module>.ko | egrep 'signer|sig_key|sig_hashalgo' || true
```

---

## Step 5 — Package the signed kernel as a `.deb`

There are two broad approaches:

### Approach 1: Post-process an existing kernel `.deb`
1. Extract the `.deb` payload
2. Replace `/boot/vmlinuz-<KVER>` with your signed kernel
3. Repack the `.deb`

Example outline:
```bash
mkdir -p work/root work/control
dpkg-deb -x proxmox-kernel-<KVER>_amd64.deb work/root
dpkg-deb -e proxmox-kernel-<KVER>_amd64.deb work/control

cp vmlinuz-<KVER>.signed work/root/boot/vmlinuz-<KVER>

dpkg-deb -b work/root proxmox-kernel-<KVER>-custom-signed_amd64.deb
```

> If you change payloads, you should also adjust versioning and ensure your repo metadata reflects your custom package.

### Approach 2: Integrate signing into the build/packaging pipeline
This is more maintainable for repeated builds:
- Sign in `debian/rules` or packaging hooks
- Emit a dedicated `-signed` package variant
- Keep signing keys out of the build container image (mount them at build time)

Proxmox itself ships Secure Boot related packaging and documentation around signed variants and setup. citeturn0search0turn0search16turn0search3

---

## Step 6 — Install and boot the signed kernel on Proxmox

Install your custom package:
```bash
dpkg -i proxmox-kernel-<KVER>-custom-signed_amd64.deb
update-grub || true
proxmox-boot-tool refresh 2>/dev/null || true
reboot
```

After reboot, validate:
```bash
uname -r
mokutil --sb-state
dmesg | grep -i 'secureboot\|Lockdown' || true
```

---

## Troubleshooting checklist

### “Depends on dwarves… not installable” (build-deps issues)
That is an APT repository / package list issue, not a signing issue. Ensure `apt-get update` ran and the correct Debian suite repos are configured.

### Kernel boots but DKMS modules fail to load
- Enroll the DKMS MOK key (or your vendor key) and rebuild DKMS modules. citeturn0search4
- Check `dmesg` for `Lockdown` / signature enforcement messages.

### “bad shim signature” / SBAT problems
These are typically shim / revocation / boot-chain issues (not kernel signing per se). Proxmox community threads document such cases; always confirm shim versions and SBAT revocations. citeturn0search8turn0search15

---

## Distribution guidance: MOK vs Microsoft-signed shim

### If you distribute to administrators (common for custom Proxmox kernels)
Use **MOK-based enrollment**:
- Fast, practical, auditable
- Users enroll your key once

### If you distribute to broad end-users (OS/appliance vendor model)
Consider Microsoft-signed shim, but expect:
- Shim review board submission workflow citeturn0search2
- Microsoft UEFI signing requirements and formal submission citeturn0search6
- Ongoing responsibility for revocation response

---

## References
- Proxmox: Secure Boot Setup citeturn0search0
- Proxmox: Administration Guide (Secure Boot support/integration) citeturn0search16
- Proxmox: Host Bootloader notes about signing modules citeturn0search12
- Proxmox forum note on `-signed` variants citeturn0search3
- Proxmox forum discussion on DKMS module signing key enrollment citeturn0search4
- shim review board process citeturn0search2
- Microsoft signing requirements referencing shim review citeturn0search6
