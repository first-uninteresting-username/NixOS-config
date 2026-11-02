# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "host-nisha";
  ids = ["host-nisha"];
  module = _: {
    nixos = {
      inputs,
      modulesPath,
      userName,
      ...
    }: {
      imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        inputs.disko.nixosModules.disko
        ./_sources/disko.nix
      ];

      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            configurationLimit = 10;
          };
          # OCI boots the removable-media fallback path; NVRAM entries are not kept.
          efi.canTouchEfiVariables = false;
        };
        initrd.availableKernelModules = ["virtio_pci" "virtio_scsi" "sd_mod" "nvme"];
        # The OCI serial console attaches to the PL011 UART.
        kernelParams = ["console=tty1" "console=ttyAMA0,115200"];
      };

      zramSwap.enable = true;

      # Dedicated key from the portable USB connection kit; revoke it here if the stick is lost.
      users.users.${userName}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBwrQNIOTZaInBX4JXE9NKhv2WLyAnpuvwP2Ku9yX3H4 nisha_usb_key"
      ];

      # Reach the desktop through an SSH tunnel; the RDP port stays closed.
      services.xrdp = {
        enable = true;
        defaultWindowManager = "startxfce4";
        openFirewall = false;
        # xrdp reloads the keymap on every connect, discarding options the session set.
        # It reads options only from a section matching the client's keyboard type.
        # US and Polish clients get the Polish layout; other layouts fall back to us.
        extraConfDirCommands = ''
          cat >> $out/xrdp_keyboard.ini <<'EOF'

          [rdp_keyboard_nisha]
          keyboard_type=4
          rdp_layouts=default_rdp_layouts
          layouts_map=rdp_layouts_map_pl
          options=caps:swapescape

          [rdp_layouts_map_pl]
          rdp_layout_us=pl
          rdp_layout_pl=pl
          EOF
        '';
      };

      system.stateVersion = "26.11";
    };
  };
}
