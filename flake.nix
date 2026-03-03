{
  description = "x86_64 disk image for Cardano with GNOME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cardano-node.url = "github:intersectmbo/cardano-node";
    cardano-addresses.url = "github:perturbing/cardano-addresses";
    cardano-signer.url = "github:perturbing/cardano-signer-nix";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixos-generators,
    cardano-node,
    cardano-addresses,
    cardano-signer,
    ...
  }: let
    system = "x86_64-linux";
  in {
    packages.${system}.default = nixos-generators.nixosGenerate {
      inherit system;
      specialArgs = inputs;
      format = "raw-efi";
      modules = [
        (
          {
            lib,
            pkgs,
            ...
          }: {
              # UEFI bootloader
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = true;

              # Quiet boot - hide verbose messages
              boot.kernelParams = [ "quiet" "udev.log_level=3" ];
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

              # Allow non-root users to read dmesg
              boot.kernel.sysctl = {
                "kernel.dmesg_restrict" = 0;
              };

              # GNOME desktop
              services.xserver.enable = true;
              services.xserver.displayManager.gdm.enable = true;
              services.xserver.displayManager.gdm.autoSuspend = false;
              services.xserver.desktopManager.gnome.enable = true;

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
              environment.systemPackages = with pkgs; [
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

                cardano-node.packages.${system}.cardano-cli
                cardano-addresses.packages.${system}."cardano-addresses:exe:cardano-address"
                cardano-signer.packages.${system}.cardano-signer
              ];

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

              system.stateVersion = "24.11";
            }
          )
        ];
      };
    };
}
