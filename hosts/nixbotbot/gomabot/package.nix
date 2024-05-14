{ pkgs, ... }:

let
  lib = pkgs.lib;
in pkgs.buildGoModule rec {
  pname = "mautrix-bot";
  version = "unstable";

  src = lib.cleanSource /state/home/projects/github/gomabot;

  buildInputs = with pkgs; [
    olm
  ];

  vendorHash= "sha256-owmJTXZKfHlxbyDYzJvOa4rhP4xhCUm8FZhQ0lZJNA4=";
}
