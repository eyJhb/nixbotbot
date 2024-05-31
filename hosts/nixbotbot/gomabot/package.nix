{ pkgs, ... }:

let
  lib = pkgs.lib;
in pkgs.buildGoModule rec {
  pname = "mautrix-bot";
  version = "unstable";

  src = lib.cleanSource ./../../../botsrc;

  buildInputs = with pkgs; [
    olm
    nixfmt
    nix
  ];

  vendorHash= "sha256-CgProDg+GNZHNhd6dHO5aHXL43ZiEqOVr7CHhn7BiB4=";
}
