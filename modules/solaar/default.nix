# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "solaar";
  ids = ["solaar"];
  module = _: {
    nixos = {
      lib,
      preservationEnable,
      userName,
      ...
    }: {
      programs.solaar = {
        enable = true;
        userService.enable = true;
      };

      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist".users.${userName}.directories = [".config/solaar"];
      };
    };
  };
  docs = ''
    Add `solaar` to a NixOS host's `ids` to manage Logitech devices with Solaar.
    Solaar starts with the graphical session with its window hidden and a tray icon.
    When preservation is enabled, the user's `.config/solaar` directory persists across reboots.
  '';
}
