# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "terminal-emulator";
  ids = ["terminal-emulator"];
  module = _: {
    home = {pkgs, ...}: {
      programs.ghostty.enable = true;
      stylix.targets.ghostty.enable = true;

      # Ghostty can report readiness before installing its SIGUSR2 handler, which systemd
      # rejects for Type=notify-reload, so the first D-Bus-activated window hangs.
      xdg.configFile."systemd/user/app-com.mitchellh.ghostty.service.d/notify.conf".text = ''
        [Service]
        Type=notify
        ExecReload=${pkgs.coreutils}/bin/kill -USR2 $MAINPID
      '';
    };
  };
}
