# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  inputs,
  ...
}: let
  Hostname = "victim";
in {
  flake.nixosConfigurations.${Hostname} = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit self inputs;
    };
    modules = [
      {_module.args.hostName = Hostname;}
      ./modules.nix
      ./hardware.nix
      self.nixosModules.agents
      self.nixosModules.audio
      self.nixosModules.bootloader
      self.nixosModules.browser
      self.nixosModules.gaming
      self.nixosModules.git
      self.nixosModules.home-manager
      self.nixosModules.IDE
      self.nixosModules.input
      self.nixosModules.languages
      self.nixosModules.llama-cpp
      self.nixosModules.locale
      self.nixosModules.moonlight
      self.nixosModules.networking-desktop
      self.nixosModules.nix
      self.nixosModules.power
      self.nixosModules.printing
      self.nixosModules.programs-desktop
      self.nixosModules.secrets
      self.nixosModules.smart
      self.nixosModules.ssh
      self.nixosModules.sudo
      self.nixosModules.tty
      self.nixosModules.update
      self.nixosModules.virtualization-desktop
      self.nixosModules.wayland
      self.nixosModules.xdg
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit self inputs;
        };
      }
    ];
  };
}
