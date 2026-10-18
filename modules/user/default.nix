# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "user";
  ids = ["user"];
  module = _: {
    nixos = {
      lib,
      userEnable,
      userName,
      userPassword,
      userHashedPasswordFile,
      userHashedPassword,
      ...
    }: {
      config = lib.mkIf userEnable {
        users = {
          mutableUsers = false;
          groups.${userName} = {
            gid = 1000;
          };
          users.${userName} = {
            isNormalUser = true;
            uid = 1000;
            group = userName;
            home = "/home/${userName}";
            homeMode = "751";
            description = userName;
            extraGroups = [
              "wheel"
              "networkmanager"
              "video"
              "audio"
              "render"
              "gamemode"
              "input"
              "kvm"
              "netdev"
            ];
            hashedPasswordFile = lib.mkDefault userHashedPasswordFile;
            hashedPassword = userHashedPassword;
            initialPassword = userPassword;
            subUidRanges = [
              {
                startUid = 100000;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = 100000;
                count = 65536;
              }
            ];
            linger = true;
          };
        };
      };
    };
  };
}
