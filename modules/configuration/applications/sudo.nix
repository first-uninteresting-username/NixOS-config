# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.sudo = _: {
      security = {
        sudo.enable = false;
        sudo-rs.enable = true;
        # Making you not need to write password over and over
        polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (subject.isInGroup("wheel")) {
              var isNixAction = action.id.indexOf("org.nixos.") == 0;
              var isSystemdAction =
                action.id.indexOf("org.freedesktop.systemd1.") == 0;
              if (isNixAction || isSystemdAction) {
                return polkit.Result.AUTH_ADMIN_KEEP;
              }
            }
          });
        '';
      };
    };
  };
}
