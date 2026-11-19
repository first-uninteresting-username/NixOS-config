# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "ntfy";
  ids = ["ntfy"];
  module = {
    ntfyUrl ? "https://ntfy.iameasytoremember.com",
    ntfyTokenPath ? "/run/secrets/NTFY_TOKEN",
    ntfyTopics ? ["vikunja" "agents"],
    ntfyAgentTopic ? "agents",
  }: {
    nixos = {
      lib,
      secretsEnable,
      userName,
      ...
    }: {
      config = lib.optionalAttrs secretsEnable {
        sops.secrets."NTFY_TOKEN" = {
          path = ntfyTokenPath;
          owner = userName;
        };
      };
    };
    home = {
      lib,
      pkgs,
      secretsEnable,
      ...
    }: let
      tokenFile = lib.escapeShellArg ntfyTokenPath;

      # An NTFY_TOKEN already in the environment wins over the sops file.
      readToken = ''
        if [ -z "''${NTFY_TOKEN-}" ] && [ -r ${tokenFile} ]; then
          NTFY_TOKEN=$(cat ${tokenFile})
          export NTFY_TOKEN
        fi
      '';

      ntfy = pkgs.symlinkJoin {
        inherit (pkgs.ntfy-sh) name;
        paths = [pkgs.ntfy-sh];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = lib.optionalString secretsEnable ''
          wrapProgram $out/bin/ntfy --run ${lib.escapeShellArg readToken}
        '';
        meta = pkgs.ntfy-sh.meta or {};
      };

      # ntfy runs the command once per message with NTFY_* variables set. Priorities 4 and 5
      # (high, urgent) map to critical notifications.
      notify = pkgs.writeShellScript "ntfy-notify" ''
        urgency=normal
        case ''${NTFY_PRIORITY-3} in
          4 | 5) urgency=critical ;;
          1 | 2) urgency=low ;;
        esac
        exec ${lib.getExe pkgs.libnotify} --app-name=ntfy --urgency="$urgency" \
          "''${NTFY_TITLE:-$NTFY_TOPIC}" "''${NTFY_MESSAGE-}"
      '';

      clientConfig = (pkgs.formats.yaml {}).generate "ntfy-client.yml" {
        default-host = ntfyUrl;
        # Per-subscription commands also apply to `ntfy subscribe --poll`, unlike default-command.
        subscribe =
          map (topic: {
            inherit topic;
            command = "${notify}";
          })
          ntfyTopics;
      };

      skill = ''
        ---
        name: ntfy
        description: Send a push notification to the user's phone and desktops through their
          self-hosted ntfy server. Use when the user asks to be notified, pinged, or alerted,
          for example when a long-running task, build, deploy, or agent session finishes or
          needs their input.
        ---

        # ntfy notifications

        The user runs ntfy at ${ntfyUrl}. Anonymous access is denied; the `ntfy` command
        reads the access token from `${ntfyTokenPath}` and uses that server by default.

        ## Topics

        - `${ntfyAgentTopic}`: messages from agents. Publish here unless the user names
          another topic.
        - `vikunja`: Vikunja task reminders. Do not publish here.

        The user's desktops and phone subscribe to these topics.

        ## Publish

        ```bash
        ntfy publish --title "Build finished" --tags white_check_mark \
          ${ntfyAgentTopic} "nixos-rebuild for victim succeeded"
        ```

        Useful flags: `--priority 1-5` (4 or 5 for failures that need attention),
        `--tags` (comma-separated emoji short codes such as `warning`, `x`, `tada`),
        `--click <url>` (opens on tap), `--markdown`, and `--delay 30m` for a later delivery.

        Without the `ntfy` command, use curl with the token file:

        ```bash
        curl -sf -H "Authorization: Bearer $(cat ${ntfyTokenPath})" \
          -H "Title: Build finished" -d "nixos-rebuild succeeded" \
          ${ntfyUrl}/${ntfyAgentTopic}
        ```

        Keep messages short: one line saying what happened and whether action is needed.
        Never include secrets, tokens, or private file contents in a notification.
      '';
    in {
      home.packages = [ntfy];
      xdg.configFile."ntfy/client.yml".source = clientConfig;

      programs.claude-code.skills.ntfy = skill;
      programs.opencode.skills.ntfy = skill;

      # The server denies anonymous access, so subscribing needs the sops token.
      systemd.user.services.ntfy-subscribe = lib.mkIf secretsEnable {
        Unit = {
          Description = "ntfy desktop notifications";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };
        Service = {
          ExecStart = "${lib.getExe ntfy} subscribe --from-config";
          Restart = "always";
          RestartSec = 10;
        };
        Install.WantedBy = ["graphical-session.target"];
      };
    };
  };
  docs = ''
    The `ntfy` host ID enables this module. It installs the ntfy CLI, points it at the
    self-hosted server at `ntfyUrl`, and adds an `ntfy` skill for Claude Code and OpenCode that
    publishes agent notifications to `ntfyAgentTopic`.

    With secrets enabled, sops-nix decrypts `NTFY_TOKEN` to `ntfyTokenPath`, and the wrapped
    `ntfy` command reads it unless `NTFY_TOKEN` is already set. A user service,
    `ntfy-subscribe`, subscribes to `ntfyTopics` and shows each message as a desktop
    notification; priorities 4 and 5 become critical notifications. The server denies
    anonymous access, so without secrets the service is not installed.
  '';
  imperativeSteps = ''
    With secrets enabled, create an access token on the ntfy server and store it in sops:

    ```bash
    ntfy token add --label nixos-desktops <user>   # inside the server container
    sops-easy secrets/secrets.yaml
    ```

    Add the `tk_…` value as `NTFY_TOKEN`, then rebuild.
  '';
}
