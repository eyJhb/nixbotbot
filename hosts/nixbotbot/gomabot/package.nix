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

  vendorHash= "sha256-hoq88KUaKD+YUKHfKdFaVXTZzz7XJ5S4wWxhGZoVw4A=";
}
