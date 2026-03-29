# Mnemonic-Based Key Generation

This guide covers a more secure method of generating Cardano payment keys using a **24-word BIP39 mnemonic phrase** (seed phrase). Unlike generating raw key files directly, this approach lets you reconstruct your keys from a memorisable (or paper-backed) word list if the encrypted USB drive is ever lost or damaged.

> **This is the approach mentioned in [SETUP.md](SETUP.md) under "Mnemonic-based key derivation".**

---

## Why use a mnemonic?

With the raw `cardano-cli address key-gen` approach from `SETUP.md`, your signing key exists only as binary files. If all copies are lost, your funds are gone permanently.

With a mnemonic:
- The 24 words _are_ the master secret. Keys are derived deterministically from them.
- You can reconstruct your keys at any time by re-running the derivation on the same words.
- The word list can be stored on paper (or stamped in metal) in a fireproof safe, independent of any USB drive.

---

## Prerequisites

- A system booted from the cold machine image
- An encrypted LUKS/F2FS partition set up on a USB drive (see [SETUP.md](SETUP.md) for instructions)
- The `cardano-seed-keygen` script (included in the image)

---

## Key Generation Steps

### 1. Navigate to the Encrypted Partition

Ensure your encrypted partition is mounted and navigate to it:

```bash
cd /run/media/$USER/encrypted
```

Create a directory for your keys:

```bash
mkdir -p cardano-keys
cd cardano-keys
```

### 2. Run the Script

To generate a **fresh** phrase and derive keys:

```bash
cardano-seed-keygen
```

To derive keys from an **existing** phrase file:

```bash
cardano-seed-keygen /path/to/recovery-phrase.prv
```

The script will:

1. Generate a fresh 24-word BIP39 recovery phrase and write it to `recovery-phrase.prv`
2. Derive the Shelley root extended private key from the phrase (`root.xprv` — deleted after use)
3. Derive the child key at derivation path `1852H/1815H/0H/0/0` (`payment.xsk` — deleted after use)
4. Convert the child key to the `cardano-cli` signing key envelope format (`payment.skey`)
5. Derive the corresponding verification key (`payment.vkey`)
6. Compute the payment key hash (`payment.hash`)

Intermediate files (`root.xprv`, `payment.xsk`) are removed automatically. The four files that remain are:

| File                  | Secret? | Purpose                                  |
|-----------------------|---------|------------------------------------------|
| `recovery-phrase.prv` | **YES** | 24-word mnemonic — the ultimate backup   |
| `payment.skey`            | **YES** | Payment signing key                      |
| `payment.vkey`            | no      | Payment verification key — share freely  |
| `payment.hash`            | no      | Payment key hash — share freely          |

### 3. Back Up the Recovery Phrase

Before doing anything else, write down the 24 words on paper:

```bash
cat recovery-phrase.prv
```

Store the paper backup in a secure, offline location (safe, safety deposit box, etc.). This is your recovery method if all USB drives fail.

### 4. Share the Verification Key and Hash with the Orchestrator

Copy the public files to the FAT partition for transfer:

```bash
cp payment.vkey payment.hash /run/media/$USER/public/
```

Or display them to copy manually:

```bash
cat payment.vkey
cat payment.hash
```

Remove them from the public partition once transferred:

```bash
rm /run/media/$USER/public/payment.vkey /run/media/$USER/public/payment.hash
```

---

## What the Script Does Internally

The derivation follows the standard Cardano Shelley key hierarchy:

```
recovery phrase (BIP39, 24 words)
        │
        ▼  cardano-address key from-recovery-phrase Shelley
root extended private key (root.xprv)
        │
        ▼  cardano-address key child 1852H/1815H/0H/0/0
child extended signing key (payment.xsk)
        │
        ▼  cardano-cli key convert-cardano-address-key --shelley-payment-key
signing key envelope (payment.skey)
        │
        ├──▶  cardano-cli key verification-key  →  payment.vkey
        └──▶  cardano-cli address key-hash      →  payment.hash
```

The derivation path `1852H/1815H/0H/0/0` is:
- `1852H` — Cardano purpose (CIP-1852)
- `1815H` — Cardano coin type
- `0H`    — account index 0
- `0`     — external chain (payment addresses)
- `0`     — address index 0

---

## Re-Deriving Keys from an Existing Phrase

If you need to re-create the key files from your recovery phrase (e.g. after USB failure), write the phrase to a file and pass it to the script:

```bash
# Write your 24 words to a file on the encrypted partition
echo "word1 word2 ... word24" > recovery-phrase.prv

cardano-seed-keygen recovery-phrase.prv
```

This skips phrase generation and writes `payment.skey`, `payment.vkey`, and `payment.hash` to the current directory. The resulting files will be identical to those originally produced from the same phrase.

---

## Security Notes

- **Never** type your recovery phrase on a networked computer. Always use the air-gapped cold machine.
- **Never** copy `recovery-phrase.prv` or `payment.skey` to the public (unencrypted) FAT partition.
- The paper phrase backup and the encrypted USB are independent security layers — both should exist.
- If someone obtains your 24 words, they can derive all your keys without the USB drive.
- Treat the paper backup with the same physical security as the USB drive itself (see [SETUP.md § Physical Security](SETUP.md)).
