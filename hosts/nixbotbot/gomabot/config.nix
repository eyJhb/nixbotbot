{ config, pkgs, lib, ... }:

let
  # options
  globalMods = [
    "@eyjhb:eyjhb.dk"
    # "@rasmus:rend.al"
  ];

  stateDir = "/var/lib/${config.mine.matrix-bot.stateDir}";
  cacheDir = "${stateDir}/cache";
  nixreplPath = "${stateDir}/nixrepl.json";

  # wrap something
  # nix build --impure --expr 'with import <nixpkgs> {}; let eval = import (pkgs.path + "/nixos/lib/eval-config.nix") { modules = []; }; opts = (nixosOptionsDoc { options = eval.options; }).optionsJSON; in runCommandLocal "options.json" {inherit opts; } "cp $opts/share/doc/nixos/options.json $out" '
  customWriteShellScript = name: inputs: text: (pkgs.writeShellApplication {
    name = name;
    runtimeInputs = inputs;
    text = text;
    excludeShellChecks = [ "SC1091" ];
    # bashOptions = [];
  }) + "/bin/${name}";

  # wrapper scripts
  scripts = rec {
    wrappers = rec {
      __ensureMod = mods: let
        modsArray = lib.concatStringsSep " " (lib.forEach mods (x: ''"${x}"''));
      in pkgs.writeShellScript "ensure-mod-helper.sh" ''
        MODS=(${modsArray})

        for m in "''${MODS[@]}"; do
            if [[ "$USERID" == "$m" ]]; then
                exit 0
            fi
        done

        exit 1
      '';
      _ensureMod = mods: script: pkgs.writeShellScript "ensure-mod-${builtins.baseNameOf script}" ''
        if ${__ensureMod mods}; then
          ${script}
        else
          echo "ERROR: User $USERID does not have access to this command"
        fi
      '';
      ensureMod = _ensureMod globalMods;

      _ensureMutex = mutex_path: script: customWriteShellScript "ensure-mutex-${builtins.baseNameOf script}" [ pkgs.util-linux ] ''
        # use the script to run as lock
        SHELL=/bin/sh flock "${mutex_path}" --command "${script}"
      '';
      ensureMutex = script: _ensureMutex script script;

      ensureTimeout = timeout_sec: script: customWriteShellScript "ensure-timeout-${builtins.baseNameOf script}" [] ''
        timeout ${builtins.toString timeout_sec} "${script}"
      '';

      ensureNoQuotes = script: customWriteShellScript "remove-quotes" [ pkgs.gnused ] ''
        ${script} | sed 's/^"\(.*\)"$/\1/g'
      '';

      captureStdoutStderr = script: pkgs.writeShellScript "capture-stdout-stderr-${builtins.baseNameOf script}" ''
        catch() {
            {
                IFS=$'\n' read -r -d ''' "''${1}";
                IFS=$'\n' read -r -d ''' "''${2}";
                (IFS=$'\n' read -r -d ''' _ERRNO_; return ''${_ERRNO_});
            } < <((printf '\0%s\0%d\0' "$(((({ shift 2; "''${@}"; echo "''${?}" 1>&3-; } | tr -d '\0' 1>&4-) 4>&2- 2>&1- | tr -d '\0' 1>&4-) 3>&1- | exit "$(cat)") 4>&1-)" "''${?}" 1>&2) 2>&1)
        }

        catch CAPTURE_STDOUT CAPTURE_STDERR ${script}
        export CAPTURE_EXIT_CODE=$?
      '';

      # formatOutput = script: customWriteShellScript "format-output" [] ''
      formatOutput = script: pkgs.writeShellScript "format-output-${builtins.baseNameOf script}" ''
        . ${captureStdoutStderr script}
        if [ "$CAPTURE_EXIT_CODE" -ne "0" ]; then
            echo "Error"
            echo 
            echo '```'
            echo "$CAPTURE_STDERR"
            echo '```'
        else
            echo "$CAPTURE_STDOUT"
        fi
      '';
    };

    # basic
    reply = what_to_say: pkgs.writeShellScript "reply" ''
      echo "${what_to_say}"
    '';

    # , 2 + 2
    _nixEvalBoilerPlate = nixreplFile: customWriteShellScript "make-nix-eval-boilerplate" [ pkgs.jq ] ''
      echo "let"
      jq -r '.variables | to_entries | map( "\t\(.key) = \(.value);") | join("\n")' < ${nixreplFile}
      echo "in"
      # jq -r '.scopes | join(" ") | "with \(.);"' < ${nixreplFile}
      printf "\t_show ( %s )" "$EXPR"
    '';


    _nixEvalParse = nixreplFile: customWriteShellScript "nix-eval.sh" [ pkgs.nix pkgs.gawk ] ''
      EXPR=$(echo "''${MESSAGE:1}" | awk '{$1=$1;print}')

      # check if repl contains `:p` at the start,
      # if so, add strict flag
      STRICT_FLAG="--eval"
      if [[ "''${EXPR:0:2}" = ":p" ]]; then
          STRICT_FLAG="--strict"
          EXPR="''${EXPR:2}"
      fi
      export STRICT_FLAG
      export EXPR
      FINAL_EXPR="$(${_nixEvalBoilerPlate nixreplFile})"
      export FINAL_EXPR
    '';

    _nixEval = nixreplFile: customWriteShellScript "nix-eval.sh" [ pkgs.nix pkgs.gawk ] ''
      . ${_nixEvalParse nixreplFile}

      nix-instantiate \
        -I nixpkgs=channel:nixos-unstable \
        --option cores 0 \
        --option fsync-metadata false \
        --option restrict-eval true \
        --option sandbox true \
        --option timeout 3 \
        --option max-jobs 0 \
        --option allow-import-from-derivation false \
        --option allowed-uris '[]' \
        --option show-trace false \
        "$STRICT_FLAG" --eval --expr "$FINAL_EXPR"
    '';
    nixEval = _nixEval nixreplPath;

    _nixEvalShow = nixreplFile: customWriteShellScript "nix-eval-show" [ pkgs.gawk ] ''
      MESSAGE=$(echo ", ''${MESSAGE:10}" | awk '{$1=$1;print}')
      export MESSAGE
      . ${_nixEvalParse nixreplFile}

      echo '```nix'
      echo "$FINAL_EXPR"
      echo -n '```'
    '';
    nixEvalShow = _nixEvalShow nixreplPath;

    nixEvalHtml = customWriteShellScript "nix-eval.sh" [ pkgs.nix pkgs.jq pkgs.pup ] ''
      CODEFENCE=$(echo "$MESSAGE" | \
                  pup --plain 'code[class="language-nix"] json{}' | \
                  jq -r '.[:1] | .[].text')

      if [[ -n "$CODEFENCE" ]]; then
        export MESSAGE=", $CODEFENCE"
        ${nixEval}
      fi
    '';

    nixEvalAddRepl = customWriteShellScript "nix-eval-add-repl" [ pkgs.gawk ] ''
      REPL_KEY="$(echo "$MESSAGE_STRIP" | cut -d '=' -f1 | awk '{$1=$1;print}')"
      REPL_VAL="$(echo "$MESSAGE_STRIP" | cut -d '=' -f2- | awk '{$1=$1;print}')"

      if [ ! "$REPL_KEY" ]; then
        echo "Key cannot be empty"
      fi

      if [ ! "$REPL_VAL" ]; then
        echo "Value cannot be empty"
      fi

      jq --arg k "$REPL_KEY" --arg v "$REPL_VAL" '.variables |= . + {$k: $v}' < ${nixreplPath} > ${nixreplPath}.bak

      # validate that new file works before setting
      export MESSAGE=", 2 + 2"
      if ! ${_nixEval "${nixreplPath}.bak"} > /dev/null; then
        echo "failed evaluation after adding variable, aborting."
        exit 0
      fi

      mv ${nixreplPath}.bak ${nixreplPath}
      echo "$REPL_KEY has been defined."
    '';

    nixEvalRemoveRepl = customWriteShellScript "nix-eval-remove-repl" [ pkgs.gawk ] ''
      REPL_KEY="$(echo "$MESSAGE_STRIP" | cut -d '=' -f1 | awk '{$1=$1;print}')"

      if [ ! "$REPL_KEY" ]; then
        echo "Key cannot be empty"
      fi

      jq --arg k "$REPL_KEY" 'del(.variables.[$k])' < ${nixreplPath} > ${nixreplPath}.bak
      mv ${nixreplPath}.bak ${nixreplPath}
      echo "$REPL_KEY has been undefined."
    '';

    # !search 
    _nixSearchPackages = limit: customWriteShellScript "nix-search.sh" [ pkgs.nix pkgs.jq ] ''
      nix search \
        -I nixpkgs=channel:nixos-unstable \
        --json nixpkgs "$MESSAGE_STRIP" | \
      jq -r --argjson limit "${builtins.toString limit}" \
        'to_entries | .[:$limit] |
                map(
                  (.key | sub("^legacyPackages.x86_64-linux.";"")) + " (\(.value.version))\n- \(.value.description)"
                ) | join("\n")'
    '';
    nixSearchPackages = _nixSearchPackages 10;

    _nixSearchWiki = limit: customWriteShellScript "nix-search-wiki" [ pkgs.curl pkgs.jq ] ''
      curl "https://wiki.nixos.org/w/api.php?action=opensearch&search=$MESSAGE_STRIP" | \
      jq -r --argjson limit "${builtins.toString limit}" \
        '.[3][:$limit] | map( "- \(.)") | join("\n")'
    '';
    nixSearchWiki = _nixSearchWiki 10;

    # _nixSearchOption = limit: customWriteShellScript "nix-search.sh" [ pkgs.nix pkgs.jq ] ''
    _nixSearchOption = limit: pkgs.writeShellScript "nix-search.sh" ''
      OPTIONS_JSON=$(${pkgs.nix}/bin/nix build \
          -I nixpkgs=channel:nixos-unstable \
          --impure \
          --no-allow-import-from-derivation \
          --restrict-eval \
          --sandbox \
          --no-link \
          --json \
          --expr 'with import <nixpkgs> {};
                    let eval = import (pkgs.path + "/nixos/lib/eval-config.nix") { modules = []; };
                    opts = (nixosOptionsDoc { options = eval.options; }).optionsJSON;
                  in runCommandLocal "options.json" {inherit opts; } "cp $opts/share/doc/nixos/options.json $out"' | \
          ${pkgs.jq}/bin/jq -r '.[].outputs.out')

      ${pkgs.jq}/bin/jq -r \
        --arg search_option "$MESSAGE_STRIP" \
        --argjson limit "${builtins.toString limit}" \
        '. | with_entries( select(.key | test($search_option; "i"))) | to_entries | .[:$limit] | map( "\(.key)\n- \(.value.description)" ) | join("\n")' < "$OPTIONS_JSON"
    '';
    nixSearchOption = _nixSearchOption 5;
  };
in {
  mine.matrix-bot = {
    enable = true;

    # picklekey and password
    environmentFile = "/var/lib/matrix-bot/auth.env";

    settings = rec {
      Homeserver = "matrix.org";
      Username = "nix-botbot";
      # locate
      # option -r
      # pr tracker
      ScriptJoinHandler  = scripts.wrappers.__ensureMod globalMods;
      ScriptHandlers = {
        "^!admin" = scripts.wrappers.ensureMod (scripts.reply "$USERID is indeed a moderator!");

        "^(?s).*${Username}.*eval.*class=\"language-nix\"" = scripts.wrappers.ensureTimeout 60 scripts.nixEvalHtml;

        "^!options?" = scripts.wrappers.ensureTimeout 60 scripts.nixSearchOption;
        "^!package" = scripts.wrappers.ensureTimeout 60 scripts.nixSearchPackages;
        "^!wiki" = scripts.wrappers.ensureTimeout 60 scripts.nixSearchWiki;
        "^!echo" = scripts.reply "$MESSAGE";
        "^(!|)ping" = scripts.reply "pong";

        # repl things
        "^, ?[A-z0-9_ ]+ ?=.+" = scripts.wrappers._ensureMutex nixreplPath scripts.nixEvalAddRepl;
        "^, ?[A-z0-9_ ]+ ?=$" = scripts.wrappers._ensureMutex nixreplPath scripts.nixEvalRemoveRepl;
        "^, ?[A-z0-9 _]+$" = scripts.wrappers.ensureNoQuotes (scripts.wrappers.formatOutput (scripts.wrappers.ensureTimeout 60 scripts.nixEval));
        "^," = scripts.wrappers.formatOutput (scripts.wrappers.ensureTimeout 60 scripts.nixEval);
        # what?
        "^!repl_show" = scripts.wrappers.formatOutput scripts.nixEvalShow;
      };
    };
  };

  systemd.services.matrix-bot = {
    # setup the cache dir
    environment.XDG_CACHE_HOME = cacheDir;

    # add boilerplate nixrepl file
    script = lib.mkBefore ''
      if [ ! -f "${nixreplPath}" ]; then
        echo "Creating nixrepl.json file"
        echo '{"variables": {"_show": "x: if lib.isDerivation x then \"<derivation ''${x.drvPath}>\" else x;"}, "scopes": ["pkgs", "lib"]}' > "${nixreplPath}"
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
      MESSAGE_STRIP="blender" ${scripts.nixSearchPackages}
      MESSAGE_STRIP="appimage" ${scripts.nixSearchOption}
      MESSAGE=", 2 + 2" ${scripts.nixEval}
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
