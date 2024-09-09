{ modulesPath, config, lib, pkgs, ... }:

let
  sources = import ./nix/sources.nix;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    
    (sources.disko + "/module.nix")
    ./nixbotbot/disk-zfs.nix

    ./nixbotbot/gomabot
  ];

  networking.hostId = "e1166ac9";
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    jq
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 75;
    algorithm = "lz4";
  };

  nix.gc.automatic = true;

  users.users.root.openssh.authorizedKeys.keys = [
    # eyjhb
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPuma8g+U8Wh+4mLvZoV9V+ngPqxjuIG4zhsbaTeXq65 eyjhb@chronos"
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCpGGdH8BpCM9pUSANM9vYA4b/V2zGJK+GGpi8N/Qp+j32TRD6UsA0g42o4tL72Hsv3PKUU5vaZaXjeSSZYpwaNCe1aR7ehBesEvcgeiU66jBQ6JfMoArF+ZreveXQvtYeqcN6Iyijcu7vyqWIcybT5yOEiylQhB2bUd5lVR9KDAW3z6zhiVPxGmC8D09uZVxsGPfAPxyKvRs6Jkq0d67nDI9yUOtRJEdMvrDDhGzHQhKRuxl+NHtYCOa9octFZMcpEssmUOS97KNgBhglSZlz4a5PKUO7NmLZEgrCjw/aAKyepRenB3a7R/20lJvsN4YsIAR/rVH6bdrYhWKOjUrXm3PFPBs7CxdMP9qs4LEM1AMJ0dTw40AE94HfvilEV3HV+WSjen1dcHJNrSQiOAfXZPVjkkmnrum6p3R1gPcezhrGuWZv/RDgJIflo6Kd3heCe9gk1tV/lYswm5l9Cpg5gIUiMd01UfXI4FvxFQcE4AIBs8UHOhorIbjDbNTeZoBxXZFWMRUTVNR37hZRBnp/Ept0WOsIhlqi0V/oGRAilVy2a0Xs9dwX785W8Q9g5weT+fUR71huTjEEQnz7/VGcOPE64mD3yh7rmxYi6wMjoG6/NxzRBs4KRux5q+MAHxl0jDCgV+0fx78xtlH9Zb3/d5cgZ4TwPeIElS4g1b5FFBQ== eyjhb@everywhere"
    # rasmus
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGee4uz+HDOj4Y4ANOhWJhoc4mMLP1gz6rpKoMueQF2J rendal@popper"
  ];

  nixpkgs.config.permittedInsecurePackages= [
    "olm-3.2.16"
  ];


  system.stateVersion = "24.05";
}
