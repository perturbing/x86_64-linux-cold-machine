{
  description = "x86_64 disk image for Cardano with GNOME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixos-generators,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system}.default = nixos-generators.nixosGenerate {
        inherit system;
        specialArgs = inputs;
        format = "raw-efi";
        modules = [
          (
            { lib, pkgs, ... }:
            {
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
                hashedPassword = "!";
                extraGroups = [ "wheel" ];
              };

              users.allowNoPasswordLogin = true;

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

              # Cardano tools and basic utilities
              environment.systemPackages = with pkgs; [
                gnome-terminal
                nautilus
                vim
                gnome-text-editor
                # add other tool here

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
