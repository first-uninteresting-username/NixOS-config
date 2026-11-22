# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}: let
  defaultHost = "git.hackclub.app";

  # The login file `fj` reads from `$XDG_DATA_HOME/forgejo-cli/keys.json`.
  keysJson = host: token:
    builtins.toJSON {
      hosts.${host} = {
        type = "Application";
        inherit token;
      };
    };
in
  mkModule {
    name = "forgejo-cli";
    ids = ["forgejo-cli"];
    state = {
      home.directories = [".local/share/forgejo-cli"];
    };
    module = {
      forgejoHost ? defaultHost,
      forgejoKeysPath ? "/run/secrets/rendered/forgejo-cli-keys.json",
    }: {
      nixos = {
        config,
        lib,
        secretsEnable,
        userName,
        ...
      }: {
        config = lib.optionalAttrs secretsEnable {
          sops = {
            secrets."forgejo_token" = {};
            templates."forgejo-cli-keys.json" = {
              content = keysJson forgejoHost config.sops.placeholder.forgejo_token;
              path = forgejoKeysPath;
              owner = userName;
            };
          };
        };
      };
      home = {
        config,
        lib,
        pkgs,
        secretsEnable,
        ...
      }: let
        # Outside a repository, commands target the Forgejo host instead of failing.
        fj = pkgs.symlinkJoin {
          inherit (pkgs.forgejo-cli) name version meta;
          paths = [pkgs.forgejo-cli];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/fj \
              --set-default FJ_FALLBACK_HOST ${lib.escapeShellArg "https://${forgejoHost}"}
          '';
        };
      in {
        home.packages = [fj];
        # The rendered secret lives outside the home directory, so sops never creates
        # root-owned parent directories there. The link is read-only for `fj auth` commands.
        xdg.dataFile."forgejo-cli/keys.json" = lib.mkIf secretsEnable {
          source = config.lib.file.mkOutOfStoreSymlink forgejoKeysPath;
        };
      };
    };
    checks = {pkgs, ...}: {
      # Catches upstream changes to the login file format.
      keys-format = pkgs.runCommand "forgejo-cli-keys-format" {} ''
        export HOME=$TMPDIR XDG_DATA_HOME=$TMPDIR/data
        mkdir -p $XDG_DATA_HOME/forgejo-cli
        cp ${pkgs.writeText "keys.json" (keysJson defaultHost "dummy")} \
          $XDG_DATA_HOME/forgejo-cli/keys.json
        ${pkgs.lib.getExe' pkgs.forgejo-cli "fj"} auth list | grep -Fx ${defaultHost}
        touch "$out"
      '';
    };
    docs = ''
      Installs the Forgejo CLI as `fj`, logged in to `forgejoHost` (Hack Club's
      `git.hackclub.app` by default). The `forgejo-cli` host ID enables it. Outside a
      repository, `fj` falls back to `forgejoHost` through `FJ_FALLBACK_HOST`.

      With secrets enabled, sops-nix renders the `forgejo_token` application token into the
      `fj` login file at `forgejoKeysPath`, and Home Manager links it to
      `~/.local/share/forgejo-cli/keys.json`. The token stays out of the Nix store, and
      `fj auth` commands cannot change the declarative login. Without secrets, run
      `fj auth login` once; `~/.local/share/forgejo-cli` persists when preservation is enabled.
    '';
    imperativeSteps = ''
      With secrets enabled, create an application token at
      `https://git.hackclub.app/user/settings/applications` and store it in sops:

      ```bash
      sops-easy secrets/secrets.yaml
      ```

      Add the token as `forgejo_token`, then rebuild.
    '';
  }
