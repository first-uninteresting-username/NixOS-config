# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "desktop-password";
  ids = ["desktop-password"];
  module = _: {
    nixos = {
      config,
      lib,
      secretsEnable,
      hostName,
      userName,
      ...
    }:
      lib.optionalAttrs secretsEnable {
        sops.secrets."sudo_password/${hostName}".neededForUsers = true;
        users.users.${userName}.hashedPasswordFile = config.sops.secrets."sudo_password/${hostName}".path;
      };
  };
}
