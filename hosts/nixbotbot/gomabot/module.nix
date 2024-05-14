{ config, pkgs, lib, ... }:

with lib.types;

let
  cfg = config.mine.matrix-bot;

  # package
  package = pkgs.callPackage ./package.nix {};

  # config file
  format = pkgs.formats.json { };
  configFile = format.generate "matrix-bot.json" cfg.settings;
in {
  options = {
    mine.matrix-bot = {
      enable = lib.mkEnableOption "matrix-bot";

      package = lib.mkOption {
        default = package;
        type = types.package;
      };

      settings = lib.mkOption {
        default = { };
        type = types.submodule {
          freeformType = format.type;
        };
      };

      environmentFile = lib.mkOption {
        type = with types; nullOr str;
        default = null;
      };

      stateDir = lib.mkOption {
        default = "matrix-bot";
        type = types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    mine.matrix-bot.settings.StateDir = "/var/lib/${cfg.stateDir}";

    users.users.matrix-bot = {
      isSystemUser = true;
      group = "matrix-bot";
      home = "/tmp";
    };
    users.groups.matrix-bot = {};

    systemd.services.matrix-bot = {
      enable = true;
      path = with pkgs; [ bash jq ];
      restartTriggers = [ configFile ];
      serviceConfig = {
        # DynamicUser = true;
        User = "matrix-bot";
        Group = "matrix-bot";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        # StateDirectory = cfg.stateDir;
      };

      script = ''
        ${cfg.package}/bin/gomabot -config ${configFile}
      '';

      description = "matrix-bot - simple script bot";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };
}
