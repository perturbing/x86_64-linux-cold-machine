{inputs, ...}: {
  perSystem = {
    system,
    config,
    ...
  }: {
    packages = {
      airgap = inputs.nixos-generators.nixosGenerate {
        inherit system;
        specialArgs = {inherit inputs system;};
        format = "raw-efi";
        modules = [
          (
            {
              lib,
              pkgs,
              inputs,
              system,
              ...
            }: {
              # UEFI bootloader
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

              # Quiet boot - hide verbose messages
              boot.kernelParams = ["quiet" "udev.log_level=3"];
              boot.consoleLogLevel = 3;

              # Plymouth for smooth boot
              boot.plymouth.enable = true;

              # Disable all networking
              networking.hostName = "cardano-workstation";
              networking.useDHCP = false;
              networking.wireless.enable = false;
              networking.networkmanager.enable = false;
              services.openssh.enable = false;
              hardware.bluetooth.enable = false;

              # Basic user setup
              users.users.nixos = {
                isNormalUser = true;
                hashedPassword = "";
                extraGroups = ["wheel" "disk"];
              };

              users.allowNoPasswordLogin = true;

              # Allow nixos user to use disk utilities without password
              security.sudo.extraRules = [
                {
                  users = ["nixos"];
                  commands = [
                    {
                      command = "/run/current-system/sw/bin/mount";
                      options = ["NOPASSWD"];
                    }
                    {
                      command = "/run/current-system/sw/bin/umount";
                      options = ["NOPASSWD"];
                    }
                    {
                      command = "/run/current-system/sw/bin/fdisk";
                      options = ["NOPASSWD"];
                    }
                    {
                      command = "/run/current-system/sw/bin/cfdisk";
                      options = ["NOPASSWD"];
                    }
                    {
                      command = "/run/current-system/sw/bin/parted";
                      options = ["NOPASSWD"];
                    }
                    {
                      command = "/run/current-system/sw/bin/gdisk";
                      options = ["NOPASSWD"];
                    }
                    {
                      command = "/run/current-system/sw/bin/sgdisk";
                      options = ["NOPASSWD"];
                    }
                  ];
                }
              ];

              # Allow wheel group to use sudo without password
              security.sudo.wheelNeedsPassword = false;

              # Allow wheel group users to perform disk operations without password
              security.polkit.enable = true;
              security.polkit.extraConfig = ''
                polkit.addRule(function(action, subject) {
                  if (subject.isInGroup("wheel") &&
                      action.id.indexOf("org.freedesktop.udisks2.") == 0) {
                    return polkit.Result.YES;
                  }
                });
              '';

              # Allow non-root users to read dmesg
              boot.kernel.sysctl = {
                "kernel.dmesg_restrict" = 0;
              };

              # GNOME desktop
              services.xserver.enable = true;
              services.displayManager.gdm.enable = true;
              services.displayManager.gdm.autoSuspend = false;
              services.desktopManager.gnome.enable = true;

              # Autologin - bypass all authentication
              services.displayManager.autoLogin.enable = true;
              services.displayManager.autoLogin.user = "nixos";

              # Disable GNOME initial setup screen
              environment.gnome.excludePackages = with pkgs; [
                gnome-initial-setup
              ];

              # Prevent session from being killed
              systemd.services."getty@tty1".enable = false;
              systemd.services."autovt@tty1".enable = false;

              # YubiKey GPG support
              services.pcscd.enable = true;
              services.udev.packages = with pkgs; [
                yubikey-personalization
                libu2f-host
              ];
              services.udev.extraRules = ''
                # YubiKey devices - Yubico vendor ID 0x1050
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="1050", TAG+="uaccess", MODE="0660", GROUP="users"
              '';
              hardware.gpgSmartcards.enable = true;
              programs.gnupg.agent = {
                enable = true;
                pinentryPackage = pkgs.pinentry-gnome3;
              };

              # Cardano tools and basic utilities
              environment.systemPackages = with pkgs; let
                cardano-cli = inputs.cardano-node.packages.${system}.cardano-cli;
                cardano-address = inputs.cardano-addresses.packages.${system}."cardano-addresses:exe:cardano-address";
                cardano-seed-keygen = pkgs.writeShellScriptBin "cardano-seed-keygen" ''
                  set -euo pipefail

                  # cardano-seed-keygen: derive Cardano payment keys from a 24-word mnemonic.
                  #
                  # Usage:
                  #   cardano-seed-keygen                    – generate a fresh phrase and derive keys
                  #   cardano-seed-keygen recovery-phrase.prv – derive keys from an existing phrase file
                  #
                  # Outputs (all written to the current directory):
                  #   recovery-phrase.prv  – the 24-word BIP39 mnemonic   (KEEP SECRET)
                  #   payment.skey         – extended payment signing key  (KEEP SECRET)
                  #   payment.vkey         – payment verification key      (safe to share)
                  #   payment.hash         – payment key hash              (safe to share)
                  #
                  # Intermediate files (root.xprv, payment.xsk) are deleted after use.

                  CARDANO_ADDRESS="${cardano-address}/bin/cardano-address"
                  CARDANO_CLI="${cardano-cli}/bin/cardano-cli"

                  EXISTING_PHRASE=""
                  if [ $# -ge 1 ]; then
                    EXISTING_PHRASE="$1"
                    if [ ! -f "$EXISTING_PHRASE" ]; then
                      echo "ERROR: phrase file '$EXISTING_PHRASE' not found." >&2
                      exit 1
                    fi
                  fi

                  # When deriving from an existing phrase, recovery-phrase.prv is not written.
                  FILES_TO_CHECK="payment.skey payment.vkey payment.hash"
                  if [ -z "$EXISTING_PHRASE" ]; then
                    FILES_TO_CHECK="recovery-phrase.prv $FILES_TO_CHECK"
                  fi

                  for f in $FILES_TO_CHECK; do
                    if [ -f "$f" ]; then
                      echo "ERROR: '$f' already exists in $(pwd). Refusing to overwrite." >&2
                      echo "Move or delete existing files before running this script." >&2
                      exit 1
                    fi
                  done

                  if [ -z "$EXISTING_PHRASE" ]; then
                    echo "==> Generating 24-word recovery phrase..."
                    "$CARDANO_ADDRESS" recovery-phrase generate --size 24 > recovery-phrase.prv
                    PHRASE_FILE="recovery-phrase.prv"
                  else
                    echo "==> Using existing phrase file: $EXISTING_PHRASE"
                    PHRASE_FILE="$EXISTING_PHRASE"
                  fi

                  echo "==> Deriving root extended private key..."
                  "$CARDANO_ADDRESS" key from-recovery-phrase Shelley < "$PHRASE_FILE" > root.xprv

                  echo "==> Deriving child key at path 1852H/1815H/0H/0/0..."
                  "$CARDANO_ADDRESS" key child 1852H/1815H/0H/0/0 < root.xprv > payment.xsk

                  echo "==> Converting to cardano-cli signing key format..."
                  "$CARDANO_CLI" key convert-cardano-address-key \
                    --shelley-payment-key \
                    --signing-key-file payment.xsk \
                    --out-file payment.skey

                  echo "==> Deriving verification key..."
                  "$CARDANO_CLI" key verification-key \
                    --signing-key-file payment.skey \
                    --verification-key-file payment.vkey

                  echo "==> Computing key hash..."
                  "$CARDANO_CLI" address key-hash \
                    --payment-verification-key-file payment.vkey > payment.hash

                  echo "==> Cleaning up intermediate files..."
                  rm -f root.xprv payment.xsk

                  echo ""
                  echo "Done. Files written to $(pwd):"
                  if [ -z "$EXISTING_PHRASE" ]; then
                    echo "  recovery-phrase.prv  (SECRET – back this up on paper or encrypted storage)"
                  fi
                  echo "  payment.skey         (SECRET – keep on encrypted partition only)"
                  echo "  payment.vkey         (public – share with orchestrator)"
                  echo "  payment.hash         (public – share with orchestrator)"
                  echo ""
                  echo "Key hash: $(cat payment.hash)"
                '';
              in [
                gnome-terminal
                nautilus
                vim
                gnome-text-editor
                # YubiKey tools
                gnupg
                yubikey-personalization
                yubikey-manager
                # Disk utilities
                parted
                gptfdisk
                zip

                cardano-cli
                cardano-address
                inputs.cardano-signer.packages.${system}.cardano-signer
                inputs.cquisitor.packages.${system}.cquisitor
                cardano-seed-keygen
              ];

              # Enable bash completion for Cardano tools
              programs.bash.interactiveShellInit = ''
                source <(cardano-cli --bash-completion-script cardano-cli)
                source <(cardano-address --bash-completion-script cardano-address)
              '';

              # Ephemeral system: all state is volatile
              boot.tmp.useTmpfs = true;
              boot.tmp.tmpfsSize = "512M";
              boot.tmp.cleanOnBoot = true;

              # Mount key directories as tmpfs (RAM-based, ephemeral)
              fileSystems."/var" = {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [
                  "mode=0755"
                  "nosuid"
                  "nodev"
                  "size=512M"
                ];
              };

              fileSystems."/home" = {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [
                  "mode=0755"
                  "nosuid"
                  "nodev"
                  "size=512M"
                ];
              };

              fileSystems."/root" = {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [
                  "mode=0700"
                  "nosuid"
                  "nodev"
                  "size=64M"
                ];
              };

              # /nix must stay on disk for boot to work
              # Only user data (/home, /var, /root) is ephemeral

              # Create necessary directories in tmpfs on boot
              systemd.tmpfiles.rules = [
                "d /home/nixos 0700 nixos users -"
                "d /root 0700 root root -"
              ];

              # Volatile journal (no persistent logs)
              services.journald.storage = "volatile";
              systemd.coredump.enable = false;

              system.stateVersion = "25.11";
            }
          )
        ];
      };

      # Alias for convenience
      default = config.packages.airgap;
    };
  };
}
