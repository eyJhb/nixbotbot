{ pkgs, ... }:

let
  lib = pkgs.lib;
in pkgs.buildGoModule rec {
  pname = "mautrix-bot";
  version = "unstable";

  # src = lib.cleanSource ./../../../botsrc;
  src = ./../../../botsrc;
  # src = pkgs.fetchGithub {
  #   owner = "eyjhb";
  #   repo = "gomabot";
  #   version = "0b75d6545f124945e369618f0fa58a6512836025";
  #   sha256 = "0000000000000000000000000000000000000000000000000000";
  # };
  # proxyVendor = true;

  buildInputs = with pkgs; [
    olm
    nixfmt
    nix
  ];

  vendorHash= "sha256-gPk4Yl2nMOak64Aa/f6j7WC1njNlyHVwiPnNUQ1fBl4=";
}
