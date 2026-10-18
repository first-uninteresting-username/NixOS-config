# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib, ...}: {
  userName = {
    type = lib.types.str;
    description = "Home Manager user name.";
    default = "user";
  };
  userEnable = {
    type = lib.types.bool;
    description = "Create the NixOS user.";
    default = false;
  };
  userPassword = {
    type = lib.types.nullOr lib.types.str;
    description = "Initial user password (public fixtures only).";
    default = null;
  };
  userHashedPassword = {
    type = lib.types.nullOr lib.types.str;
    description = "User password hash.";
    default = null;
  };
  userHashedPasswordFile = {
    type = lib.types.nullOr lib.types.path;
    description = "Path to the user's password hash file.";
    default = null;
  };
  preservationEnable = {
    type = lib.types.bool;
    description = "Persist state under /persist.";
    default = false;
  };
  homeStateVersion = {
    type = lib.types.str;
    description = "Home Manager compatibility version.";
    default = "26.11";
  };
}
