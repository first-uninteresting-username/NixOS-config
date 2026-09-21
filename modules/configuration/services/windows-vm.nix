# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.windows-vm = {
      lib,
      config,
      pkgs,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          directories = [
            "/var/lib/libvirt"
          ];
        };
      };
      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          # Host-arch only QEMU, saves a lot of disk space compared to the default
          package = lib.mkDefault pkgs.qemu_kvm;
          # Windows 11 refuses to install without a TPM 2.0 device
          swtpm.enable = true;
        };
      };
      programs.virt-manager.enable = true;
      users.users.${config.custom.user.name}.extraGroups = [
        "libvirtd"
        "kvm"
      ];
    };
  };
}
