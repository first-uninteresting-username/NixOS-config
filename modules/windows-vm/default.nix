# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "windows-vm";
  ids = ["windows-vm"];
  state = {
    nixos.directories = [
      # Domain definitions, NVRAM, emulated TPM state, networks and disk images.
      "/var/lib/libvirt"
      # Certificate authority that signs emulated TPM endorsement keys.
      "/var/lib/swtpm-localca"
    ];
  };
  module = {
    windowsVmMemoryMiB ? 8192,
    windowsVmCores ? 4,
    windowsVmThreads ? 2,
    windowsVmDiskSize ? "128G",
    windowsVmTimeZone ? "Central European Standard Time",
    # Polish (Programmers), the layout matching the xkb "pl" layout.
    windowsVmInputLocale ? "0415:00000415",
    # Generic Windows 11 Pro key: selects the edition without activating it.
    windowsVmProductKey ? "VK7JG-NPHTM-C97JM-9MPGT-3V66T",
  }: {
    nixos = {
      config,
      lib,
      pkgs,
      userName,
      ...
    }: let
      vm = import ./_vm.nix {
        inherit pkgs lib;
        accountName = userName;
        memoryMiB = windowsVmMemoryMiB;
        cores = windowsVmCores;
        threads = windowsVmThreads;
        timeZone = windowsVmTimeZone;
        inputLocale = windowsVmInputLocale;
        productKey = windowsVmProductKey;
      };
      libvirt = config.virtualisation.libvirtd.package;
      virsh = "virsh --connect qemu:///system";

      install = pkgs.writeShellApplication {
        name = "windows-vm-install";
        runtimeInputs = [libvirt pkgs.coreutils];
        text = ''
          if [ ! -r ${vm.installIsoPath} ]; then
            echo "Place the Windows 11 ISO at ${vm.installIsoPath} first." >&2
            exit 1
          fi
          if [ "$(${virsh} domstate ${vm.name})" != "shut off" ]; then
            echo "The ${vm.name} domain is already running." >&2
            exit 1
          fi
          ${virsh} start ${vm.name}
          # An empty disk falls through to the ISO, whose boot loader waits for a key press.
          for _ in $(seq 15); do
            sleep 1
            ${virsh} send-key ${vm.name} KEY_ENTER >/dev/null
          done
          echo "Setup is running unattended. Watch it with virt-manager."
        '';
      };
    in {
      virtualisation = {
        libvirtd = {
          enable = true;
          qemu.swtpm.enable = true;
        };
        spiceUSBRedirection.enable = true;
      };
      programs.virt-manager.enable = true;
      users.users.${userName}.extraGroups = ["libvirtd"];
      environment.systemPackages = [install];

      # An interrupted first run leaves an empty key that blocks libvirtd from starting.
      # Removing it lets virt-secret-init-encryption generate a new one.
      systemd.services.libvirt-drop-empty-secrets-key = {
        description = "Remove an empty libvirt secrets encryption key";
        wantedBy = ["virt-secret-init-encryption.service"];
        before = ["virt-secret-init-encryption.service"];
        serviceConfig.Type = "oneshot";
        script = ''
          key=/var/lib/libvirt/secrets/secrets-encryption-key
          if [ -f "$key" ] && [ ! -s "$key" ]; then
            rm "$key"
          fi
        '';
      };

      systemd.services.windows-vm = {
        description = "Define the Windows libvirt domain";
        wantedBy = ["multi-user.target"];
        requires = ["libvirtd.service"];
        after = ["libvirtd.service"];
        path = [libvirt config.virtualisation.libvirtd.qemu.package pkgs.e2fsprogs];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p ${vm.imagesDir}
          # Avoid copy-on-write fragmentation of the disk image on Btrfs.
          chattr +C ${vm.imagesDir} 2>/dev/null || true
          if [ ! -e ${vm.diskPath} ]; then
            qemu-img create -f qcow2 ${vm.diskPath} ${windowsVmDiskSize}
          fi

          if ! ${virsh} net-info default >/dev/null 2>&1; then
            ${virsh} net-define ${libvirt}/var/lib/libvirt/qemu/networks/default.xml
          fi
          ${virsh} net-autostart default
          if ! ${virsh} net-info default | grep -Eq '^Active:\s+yes'; then
            ${virsh} net-start default
          fi

          ${virsh} define ${vm.domain}
        '';
      };
    };
  };
  checks = {
    lib,
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      default = let
        vm = import ./_vm.nix {
          inherit pkgs lib;
          accountName = "fixture & <user>";
          memoryMiB = 4096;
          cores = 2;
          threads = 1;
          timeZone = "UTC";
          inputLocale = "0409:00000409";
          productKey = "VK7JG-NPHTM-C97JM-9MPGT-3V66T";
        };
      in
        # Malformed XML only surfaces when libvirt or Windows Setup reads it.
        pkgs.runCommand "windows-vm-xml" {
          nativeBuildInputs = [pkgs.libvirt pkgs.libxml2];
        } ''
          virt-xml-validate ${vm.domain} domain
          xmllint --noout ${vm.autounattend}
          xmllint --xpath 'string(//*[local-name()="LocalAccount"]/*[local-name()="Name"])' \
            ${vm.autounattend} | grep -Fxq 'fixture & <user>'
          touch "$out"
        '';
    };
  docs = ''
    Runs a Windows 11 guest under libvirt. The `windows-vm` service defines the `windows`
    domain on every boot and switch, creates its sparse qcow2 disk, and starts libvirt's
    `default` NAT network. Changes made in virt-manager are replaced on the next definition;
    change the module arguments instead.

    The guest uses UEFI with Secure Boot and Microsoft keys, an emulated TPM 2.0, VirtIO
    disk and network, SPICE graphics, and Hyper-V enlightenments. A generated installation
    disc carries the VirtIO drivers and an `autounattend.xml` that installs Windows 11 Pro
    without prompts. It creates a local administrator named after the host user, with no
    password, and installs the VirtIO guest tools at the first sign-in.

    Members of the `libvirtd` group manage the domain with virt-manager or
    `virsh --connect qemu:///system`. With preservation enabled, `/var/lib/libvirt` keeps
    the disk image, NVRAM, and TPM state.
  '';
  imperativeSteps = ''
    Microsoft blocks scripted ISO downloads, so fetch the installation image manually:

    1. Download the Windows 11 multi-edition ISO (English, x64) from
       <https://www.microsoft.com/software-download/windows11> and compare its SHA-256
       with the hash listed on that page.
    2. Copy it to `/var/lib/libvirt/images/windows-11.iso`.
    3. Run `windows-vm-install` and watch setup in virt-manager. Windows restarts several
       times and signs in automatically when it finishes.
    4. Set a password for the Windows account. The ISO can be deleted afterwards.
  '';
}
