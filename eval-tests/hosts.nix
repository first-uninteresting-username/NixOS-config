# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
let
  hostTests = host: user: graphical: workstation: let
    home = ["home-manager" "users" user];
    expect = name: option: expected: {
      name = "${host}-${name}";
      value = {inherit host option expected;};
    };
  in
    builtins.listToAttrs [
      (expect "gnome" ["services" "desktopManager" "gnome" "enable"] graphical)
      (expect "gdm" ["services" "displayManager" "gdm" "enable"] graphical)
      (expect "networkmanager" ["networking" "networkmanager" "enable"] true)
      (expect "firewall" ["networking" "firewall" "enable"] true)
      (expect "dbus" ["services" "dbus" "enable"] true)
      (expect "pipewire" ["services" "pipewire" "enable"] graphical)
      (expect "wireplumber" ["services" "pipewire" "wireplumber" "enable"] graphical)
      (expect "printing" ["services" "printing" "enable"] workstation)
      (expect "avahi" ["services" "avahi" "enable"] graphical)
      (expect "podman" ["virtualisation" "podman" "enable"] workstation)
      (expect "preservation" ["preservation" "enable"] workstation)
      (expect "nh" ["programs" "nh" "enable"] workstation)
      (expect "normal-user" ["users" "users" user "isNormalUser"] true)
      (expect "home-manager" (home ++ ["programs" "home-manager" "enable"]) true)
      (expect "nushell" (home ++ ["programs" "nushell" "enable"]) true)
      (expect "home-ssh" (home ++ ["programs" "ssh" "enable"]) workstation)
      (expect "home-gnome-shell" (home ++ ["programs" "gnome-shell" "enable"]) graphical)
      (expect "distrobox" (home ++ ["programs" "distrobox" "enable"]) workstation)
    ];
in
  hostTests "armin" "nixi" true true
  // hostTests "victim" "nixi" true true
  // hostTests "john" "nixos" true false
  // hostTests "wall-e" "nixos" false false
