# Ephemeral Air-Gapped Cardano Workstation

A bootable NixOS image designed for secure, offline Cardano operations. Features ephemeral storage, GNOME desktop, and pre-installed Cardano tools.

## Features

- **Air-gapped**: All networking disabled (WiFi, Bluetooth, Ethernet)
- **Ephemeral storage**: `/home`, `/var`, and `/root` are tmpfs - all user data wiped on reboot
- **Auto-login**: Boots directly into GNOME desktop with no password prompts
- **Cardano tools**: Pre-installed with cardano-cli, cardano-address, and cardano-signer
- **Minimal**: Only essential packages included

## Use Case

Ideal for cold wallet operations, offline transaction signing, and key generation where you need a clean, isolated environment that leaves no traces after shutdown.

## Getting Started

### 1. Download the Image

Download the latest pre-built image from the releases:

```bash
# Download the compressed image (1.8GB download)
curl -L -O https://github.com/perturbing/x86_64-linux-cold-machine/releases/download/v0.2.0/nixos.img.zst
```

### 2. Decompress the Image

```bash
# Install zstd if needed
# Linux: Use your package manager (apt install zstd, dnf install zstd, etc.)
# macOS: brew install zstd

# Decompress the image (~11GB after decompression)
unzstd -c nixos.img.zst > nixos.img
```

### 3. Verify the Image

⚠️ **CRITICAL**: Always verify the SHA256 hash before writing to USB. If it doesn't match, do not use the image.

```bash
# Verify the SHA256 hash (Linux)
echo "ac0f647246832c5563d0937d114de2cadc26fb38d7a3673788922d9f5111f6ca  nixos.img" | sha256sum -c

# Or on macOS
echo "ac0f647246832c5563d0937d114de2cadc26fb38d7a3673788922d9f5111f6ca  nixos.img" | shasum -a 256 -c
```

If the hash matches, you'll see `nixos.img: OK`. You now have a verified image ready to write to a USB drive.

### 4. Write to USB

⚠️ **WARNING**: This will completely erase the target device!

**Linux:**

Replace `/dev/sda` with your actual USB device (check with `lsblk`):

```bash
# If you see MOUNTPOINTS on /dev/sda or /dev/sdaX run below for each
sudo umount /dev/sdaX 2>/dev/null || true

# Wipe existing filesystem signatures
sudo wipefs -a /dev/sda

# Write the image (this will take several minutes)
sudo dd if=nixos.img of=/dev/sda bs=16M status=progress conv=fsync

# Ensure all writes are flushed
sync

# Given that we write an OS of size ~11gb to a disk that is larger
# if you do the below command it will give a `GPT PMBR size mismatch`
# Warning, this because we generated the image without knowing the size
# of the target USB.
sudo fdisk -l /dev/sda

# You can fix this by running
sudo sgdisk -e /dev/sda
sudo partprobe /dev/sda
```

**macOS:**

Replace `/dev/diskN` with your actual USB device (check with `diskutil list`):

```bash
# Identify your USB device
diskutil list

# Unmount the disk (NOT eject - just unmount)
diskutil unmountDisk /dev/diskN

# Write the image (this will take several minutes)
sudo dd if=nixos.img of=/dev/rdiskN bs=16m

# rdiskN (with 'r') is the raw device and is faster than diskN

# Eject the disk when done
diskutil eject /dev/diskN

# Note: The GPT PMBR size mismatch fix requires gdisk and parted (brew install gptfdisk parted)
# but is optional - the USB will work fine without it
```

## What's Included

- **Desktop**: GNOME with Terminal, Nautilus file manager, and Text Editor
- **Cardano Tools**:
  - `cardano-cli` - Cardano node CLI
  - `cardano-address` - Address derivation and inspection
  - `cardano-signer` - Transaction signing utilities
- **Utilities**: vim

## Hardware Requirements

- **RAM**: Minimum 4GB recommended (tmpfs uses RAM for storage)
- **USB**: 16GB+ for the bootable image
- **Architecture**: x86_64 (Intel/AMD 64-bit)

## Boot and Usage

1. Boot from the USB drive (may need to adjust BIOS/UEFI boot order)
2. System will automatically log into GNOME desktop
3. Open Terminal to use Cardano tools
4. **Remember**: All work is lost on shutdown - save important data to external media

## Security Notes

- Networking is completely disabled at the system level
- No persistent logs (journald uses volatile storage)
- User home directory is wiped on each boot
- `/nix` remains on disk for system software, but contains no user data

## Advanced: Building from Source

For users who want to verify the entire build process end-to-end or customize the image:

### Requirements

- NixOS or a system with Nix package manager installed
- Sufficient disk space (~15GB for build artifacts)

### Build Instructions

```bash
# Clone the repository
git clone https://github.com/perturbing/x86_64-linux-cold-machine.git
cd x86_64-linux-cold-machine

# Build the image
nix build

# This creates result/nixos.img - a raw EFI disk image
# To write it to USB, use the same instructions as above but with:
# if=./result/nixos.img instead of if=nixos.img
```

Building from source allows you to:
- Audit the entire build configuration
- Verify reproducibility
- Customize the included packages or settings
- Ensure no supply chain tampering
