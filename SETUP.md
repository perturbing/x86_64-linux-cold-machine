# Post-Boot Setup Instructions

This guide walks you through setting up a USB drive with a public FAT partition and an encrypted F2FS partition after booting the image.

## Prerequisites

- A bootable system running the cold machine image
- An empty USB drive

## Setup Steps

### 1. Connect the USB Drive

Plug in your empty USB drive to the system.

### 2. Open GNOME Disks

Launch the GNOME Disks utility:

```bash
gnome-disks
```

Or search for "Disks" in your application menu.

### 3. Select Your USB Drive

In the Disks interface:
- Locate your USB drive in the left sidebar
- Click on it to select it
- **Warning**: Make sure you've selected the correct drive to avoid data loss

### 4. Delete Existing Partitions (if any)

If the USB drive has existing partitions:
- Select each partition
- Click the "-" (minus) button to delete it
- Repeat until all partitions are removed

### 5. Create the Public FAT Partition

1. Click the "+" (plus) button to create a new partition
2. Set the partition size to **2 GB** (2000 MB)
3. Set the filesystem type to **FAT** (or FAT32)
4. Set the partition name/label to **public**
5. Click "Create" to confirm

### 6. Create the Encrypted LUKS Partition

1. Click the "+" (plus) button on the remaining free space
2. Use all remaining space for this partition
3. Select **Internal disk for use with Linux systems only (Ext4)**
4. Enable the **Password protect volume (LUKS)** option
5. Enter a strong passphrase when prompted
6. **Important**: Store this passphrase securely - you cannot recover data without it
7. After the LUKS volume is created, format it with **F2FS**:
   - Select the unlocked LUKS volume
   - Click the gear icon and choose "Format Partition"
   - Select **F2FS** as the filesystem type
   - Set the partition name/label to **encrypted**
   - Click "Format" to confirm

### 7. Verify the Setup

Your USB drive should now have:
- A 2 GB FAT partition named "public" (accessible without password)
- A LUKS-encrypted partition with F2FS filesystem named "encrypted"

## Using Your USB Drive

### Mounting the Public Partition

The public partition will mount automatically when you plug in the USB drive, or you can mount it manually through the Disks utility.

### Mounting the Encrypted Partition

1. In GNOME Disks, select the LUKS partition
2. Click the "play" button to unlock it
3. Enter your passphrase
4. The F2FS partition will become available and can be mounted

### Unmounting

Always unmount both partitions before removing the USB drive:
1. In GNOME Disks, unmount the F2FS partition (if mounted)
2. Lock the LUKS volume
3. Unmount the public partition
4. Click "Power Off" on the drive before physically removing it

## Cardano Key Generation

After setting up your USB drive, you'll need to generate Cardano keys and share the verification key with the orchestrator.

### 1. Navigate to the Encrypted Partition

Ensure your encrypted partition is mounted, then navigate to it:

```bash
cd /run/media/$USER/encrypted
```

Create a directory for your keys:

```bash
mkdir -p cardano-keys
cd cardano-keys
```

### 2. Generate Payment Keys

Generate a new payment key pair using cardano-cli:

```bash
cardano-cli address key-gen \
  --verification-key-file payment.vkey \
  --signing-key-file payment.skey
```

This creates two files:
- `payment.skey` - **Private signing key** (keep secure, never share)
- `payment.vkey` - **Public verification key** (safe to share)

### 3. (Optional) Generate Stake Keys

If you need staking functionality:

```bash
cardano-cli stake-address key-gen \
  --verification-key-file stake.vkey \
  --signing-key-file stake.skey
```

### 4. Verify Key Generation

List the generated keys:

```bash
ls -la
```

You should see your `.vkey` and `.skey` files.

### 5. Share Verification Key with Orchestrator

Copy the verification key to the public partition for easy sharing:

```bash
cp payment.vkey /run/media/$USER/public/
```

Alternatively, display the verification key content to manually share:

```bash
cat payment.vkey
```

You can now:
- Send the `payment.vkey` file to the orchestrator via email or secure file transfer
- Copy the content and paste it into the orchestrator's interface
- The orchestrator only needs the `.vkey` file, never the `.skey` file

### 6. Secure Your Private Keys

**Critical security steps:**

1. Verify the signing keys are only on the encrypted partition:
   ```bash
   ls -la /run/media/$USER/encrypted/cardano-keys/*.skey
   ```

2. **Never** copy `.skey` files to the public partition or any unencrypted location

3. Remove the verification key from the public partition after sharing:
   ```bash
   rm /run/media/$USER/public/payment.vkey
   ```

4. **Create multiple backup copies** of your signing keys on separate encrypted LUKS volumes:
   ```bash
   # After setting up a second USB stick with encrypted LUKS partition
   cp /run/media/$USER/encrypted/cardano-keys/*.skey /run/media/$USER/encrypted-backup/cardano-keys/
   ```

   **Critical**: You must maintain at least 2-3 copies of your signing keys on different USB sticks:
   - USB drives can fail mechanically or electronically
   - A single USB stick can be lost, stolen, or damaged
   - Without your signing keys, you permanently lose access to your funds
   - Each backup USB should have its own LUKS-encrypted partition
   - Store backup USB sticks in different physical locations

## Security Notes

### Digital Security

- The public partition is **not encrypted** and accessible to anyone
- Only store non-sensitive data on the public partition
- The encrypted partition requires the passphrase to access
- If you forget the passphrase, the encrypted data cannot be recovered
- Consider keeping a secure backup of your passphrase
- **Never share or expose your `.skey` (signing key) files**
- Only the `.vkey` (verification key) files should be shared with the orchestrator
- Keep your signing keys exclusively on the encrypted partition

### Physical Security

**Your USB sticks containing signing keys are bearer instruments** - anyone with physical access can potentially access your funds.

**Mandatory precautions:**

- **Store USB sticks in secure locations**: Use locked safes, safety deposit boxes, or other secure storage
- **Distribute backups geographically**: Keep backup USB sticks in different physical locations (e.g., home safe, bank vault, trusted location)
- **Protect against theft**: Treat these USB sticks like cash or jewelry - they have direct financial value
- **Protect against damage**: Keep away from magnets, water, extreme temperatures, and physical stress
- **Protect against loss**: Always know where your USB sticks are; never carry them unnecessarily
- **Trust no one**: Assume anyone with physical access to an unlocked USB stick can copy your keys
- **Secure your environment**: Lock the cold machine when stepping away; shutdown and secure USB sticks when not in use

**Hardware failure is inevitable:**

- USB flash drives have limited lifespans (typically 3,000-100,000 write cycles)
- Even unused drives can fail due to charge leakage over time (5-10 years)
- Mechanical damage, electrical surges, and manufacturing defects can cause sudden failure
- **This is why multiple backup copies on separate devices are mandatory, not optional**

**Remember**: If all copies of your signing keys are lost or destroyed, your funds are permanently unrecoverable. No one can help you - not Cardano, not IOHK, not anyone.

## Advanced Security Practices

This document covers a basic cold storage setup suitable for most users. However, there are more advanced security practices available for those requiring higher security levels or different operational requirements:

### Out of Scope for This Guide

The following advanced techniques are **not covered** in this document but may be worth investigating based on your security needs:

- **Mnemonic-based key derivation**: Using `cardano-address` to generate keys from BIP39 mnemonic phrases (12-24 word seed phrases), allowing recovery from memorizable words instead of binary key files

- **Hardware security keys**: Dedicated cryptographic hardware devices such as:
  - YubiKey integration with GPG encryption for two-factor authentication before accessing signing keys
  - Hardware USB keys with physical PIN pads that require both physical possession and PIN knowledge
  - Hardware wallets with secure element chips designed specifically for cryptocurrency key storage

- **Multi-signature schemes**: Requiring multiple independent keys to authorize transactions (M-of-N signing)

- **Shamir's Secret Sharing**: Splitting signing keys into multiple shares where a threshold number of shares is required to reconstruct the key

- **Tamper-evident hardware**: Specialized USB devices with physical tamper detection mechanisms

These advanced approaches can provide additional layers of security, improved key recovery options, or protection against different threat models. They also introduce additional complexity, cost, and potential failure modes. Research thoroughly before implementing any advanced security scheme.

For most users managing moderate-value Cardano assets, the encrypted USB approach described in this document provides a reasonable balance of security and usability.
