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

## Building the Image

```bash
nix build
```

This creates `result/nixos.img` - a raw EFI disk image ready to write to USB.

## Writing to USB

⚠️ **WARNING**: This will completely erase the target device!

Replace `/dev/sda` with your actual USB device (check with `lsblk`):

```bash
# if you see MOUNTPOINTS on /dev/sda or /dev/sdaX run below for each
sudo umount /dev/sdaX 2>/dev/null || true

# Wipe existing filesystem signatures
sudo wipefs -a /dev/sda

# Write the image (this will take several minutes)
sudo dd if=./result/nixos.img of=/dev/sda bs=16M status=progress conv=fsync

# Ensure all writes are flushed
sync

# Given that we write an OS of size ~11gb to a disk that is larger
# if you do the below command it will give a `GPT PMBR size mismatch`
# Warning, this because we generated the image without knowing the size
# of the target usb.
sudo fdisk -l /dev/sda

# You can fix this by running
sudo sgdisk -e /dev/sda
sudo partprobe /dev/sda
```

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
