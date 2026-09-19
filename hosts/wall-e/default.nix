# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  inputs,
  ...
}: let
  Hostname = "wall-e";
in {
  flake.nixosConfigurations.${Hostname} = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit self inputs;
      inherit Hostname;
    };
    modules = [
      {_module.args.hostName = Hostname;}
      ./configuration.nix
      ./modules.nix
      self.nixosModules.input
      self.nixosModules.iso-terminal
      self.nixosModules.home-manager
      self.nixosModules.locale
      self.nixosModules.networking-minimal
      self.nixosModules.nix
      self.nixosModules.power
      self.nixosModules.secretless-git
      self.nixosModules.ssh-debug
      self.nixosModules.sudo
      self.nixosModules.tty
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

  flake.packages.x86_64-linux.${Hostname} =
    self.nixosConfigurations.${Hostname}.config.system.build.isoImage;
}
