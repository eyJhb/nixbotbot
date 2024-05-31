{ config, pkgs, lib, ... }:

let
  # options
  globalMods = [
    "@eyjhb:eyjhb.dk"
  ];
  replMods = [
    "@rasmus:rend.al"
  ];

  stateDir = "/var/lib/${config.mine.matrix-bot.stateDir}";
  cacheDir = "${stateDir}/cache";
  nixreplPath = "${stateDir}/nixrepl.json";
in {
  mine.matrix-bot = {
    enable = true;

    # picklekey and password
    environmentFile = "/var/lib/matrix-bot/auth.env";

    settings = rec {
      Homeserver = "matrix.org";
      Username = "nix-botbot";
      Admins = globalMods;
      ReplAdmins = replMods;
    };
  };

  # enable for search of options and packages
  nix.settings.experimental-features = ["nix-command" "flakes"];

  systemd.services.matrix-bot = {
    # setup the cache dir
    environment.XDG_CACHE_HOME = cacheDir;

    # add boilerplate nixrepl file
    script = lib.mkBefore ''
      if [ ! -f "${nixreplPath}" ]; then
        echo "Creating nixrepl.json file"
        echo '{}' > "${nixreplPath}"
      fi
    '';
  };

  systemd.services.matrix-bot-nix-populate-cache = {
    environment.XDG_CACHE_HOME = cacheDir;

    # use same user
    serviceConfig = {
      User = config.systemd.services.matrix-bot.serviceConfig.User;
      Group = config.systemd.services.matrix-bot.serviceConfig.Group;
    };

    # make basic nix search
    script = ''
      ${pkgs.nix}/bin/nix search -I nixpkgs=channel:nixos-unstable --json nixpkgs blender
      ${pkgs.nix}/bin/nix-instantiate -I nixpkgs=channel:nixos-unstable --eval --expr '(import <nixpkgs> {}).hello.version'
      ${pkgs.nix}/bin/nix-instantiate -I home-manager=flake:github:nix-community/home-manager --expr '(import <home-manager> {}).docs'
    '';
  };

  systemd.timers.matrix-bot-nix-populate-cache = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = [ "*:0/5"];
      Persistent = true;
      Unit = "matrix-bot-nix-populate-cache.service";
    };
  };
}
