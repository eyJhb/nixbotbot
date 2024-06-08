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

  vendorHash= "sha256-JKi4QTKr9skT6iP7dyC6lzrxEzdrzVQKDcH5j1nSDMM=";
}
