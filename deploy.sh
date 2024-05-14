#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq nixos-anywhere
set -ex

USERNAME="root"
IP="65.108.221.240"
IP="135.181.200.255"

if [ "$1" = "initial-deploy" ]; then
    echo "Initial deployment..."
    # NIV_NIXPKGS="(import ((import ./nixbotbot/nix/sources.nix).nixpkgs + \"/nixos\" ) {})"
    # NIX_TOP_LEVEL_PATH=$(nix build --impure -I nixos-config=./nixbotbot/configuration.nix --json --expr "$NIV_NIXPKGS.config.system.build.toplevel" | jq -r '.[].outputs.out')
    # NIX_DISKO_SCRIPT=$(nix build --impure -I nixos-config=./nixbotbot/configuration.nix --json --expr "$NIV_NIXPKGS.config.system.build.diskoScriptNoDeps" | jq -r '.[].outputs.out')
    NIX_TOP_LEVEL_PATH=$(nix build --impure -I nixos-config=./nixbotbot/configuration.nix --json --expr "(import <nixpkgs/nixos> {}).config.system.build.toplevel" | jq -r '.[].outputs.out')
    NIX_DISKO_SCRIPT=$(nix build --impure -I nixos-config=./nixbotbot/configuration.nix --json --expr "(import <nixpkgs/nixos> {}).config.system.build.diskoScriptNoDeps" | jq -r '.[].outputs.out')

    nixos-anywhere --store-paths "$NIX_DISKO_SCRIPT" "$NIX_TOP_LEVEL_PATH" "$USERNAME@$IP"
else
    echo "Deploying..."
    REBUILD_ACTION="switch"
    if [ -n "$1" ]; then
        REBUILD_ACTION="$1"
    fi
    nixos-rebuild \
        -I "nixpkgs=$(jq -r '.nixpkgs.url' ./hosts/nix/sources.json)" \
        -I nixos-config=./hosts/nixbotbot.nix \
        "$REBUILD_ACTION" --target-host "$USERNAME@$IP"
fi
