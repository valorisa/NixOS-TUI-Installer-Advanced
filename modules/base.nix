{ config, lib, pkgs, ... }:

let
  bootloader  = "{{BOOTLOADER}}";
  networkMode = "{{NETWORK_MODE}}";
  luksEnabled = "{{LUKS_ENABLED}}" == "true";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = bootloader == "systemd-boot";
  boot.loader.grub.enable = bootloader == "grub-efi";
  boot.loader.grub.efiSupport = bootloader == "grub-efi";
  boot.loader.grub.device = "nodev";

  networking.hostName = "{{HOSTNAME}}";
  networking.networkmanager.enable = networkMode == "networkmanager";
  systemd.network.enable = networkMode == "networkd";

  boot.initrd.luks.devices."cryptroot" = lib.mkIf luksEnabled {
    device = "/dev/disk/by-partlabel/disko_luks";
    preLVM = true;
    allowDiscards = true;
  };

  users.mutableUsers = false;
  users.users.root.hashedPassword = "{{ROOT_PASSWORD_HASH}}";
  users.users."{{USERNAME}}" = {
    isNormalUser = true;
    hashedPassword = "{{USER_PASSWORD_HASH}}";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = true;

  environment.systemPackages = with pkgs; [
    git vim curl
  ];

  system.stateVersion = "24.11";
}