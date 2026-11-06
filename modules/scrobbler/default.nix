# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "scrobbler";
  ids = ["scrobbler"];
  state = {
    # Holds the libre.fm session from `mpris-scrobbler-signon`.
    home.directories = [
      ".local/share/mpris-scrobbler"
    ];
  };
  module = _: {
    home = {
      lib,
      pkgs,
      ...
    }: {
      home.packages = [pkgs.mpris-scrobbler];

      systemd.user.services.mpris-scrobbler = {
        Unit = {
          Description = "MPRIS scrobbler for libre.fm";
          Documentation = "man:mpris-scrobbler(1)";
          Requires = ["dbus.socket"];
          After = ["dbus.socket"];
          StartLimitIntervalSec = 60;
          StartLimitBurst = 5;
        };
        Service = {
          ExecStart = lib.getExe pkgs.mpris-scrobbler;
          ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = 2;
          CPUQuota = "1%";
        };
        Install.WantedBy = ["default.target"];
      };
    };
  };
  docs = ''
    Add `scrobbler` to a host's `ids` to scrobble tracks from any MPRIS player with
    mpris-scrobbler, a user service that supports libre.fm, ListenBrainz, and Last.fm.

    Sign in once per host, then restart the service:

    ```bash
    mpris-scrobbler-signon token librefm
    mpris-scrobbler-signon session librefm
    mpris-scrobbler-signon enable librefm
    systemctl --user restart mpris-scrobbler
    ```

    The first command opens the libre.fm authorization page in a browser; approve it before
    running the second. Credentials live in `~/.local/share/mpris-scrobbler/credentials`, which
    persists across reboots when preservation is enabled.
  '';
}
