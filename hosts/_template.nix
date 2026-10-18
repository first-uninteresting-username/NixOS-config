# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  name = "example";
  role = "nixos";
  system = "x86_64-linux";
  ids = ["home-manager" "hostname" "user" "host-example"];
  args = {
    userName = "user";
    userEnable = true;
    homeStateVersion = "26.11";
    # Supply credentials appropriate to the intended host.
  };
}
