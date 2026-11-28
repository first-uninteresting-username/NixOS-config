# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "syncthing";
  ids = ["syncthing"];
  state.home.directories = ["sync" ".config/syncthing"];
  module = {
    # Device IDs come from each host's committed certificate in `_certs/`. The Orchard device
    # generated its own key; its sync port is an Orchard public port on the Orchard host.
    syncthingDevices ? {
      armin.id = "WRQUGMQ-MYVYBZS-K7FLP4B-WCRGX7N-XKHIXT7-V5IIYU4-VIA3XRI-2KLJZQB";
      victim.id = "QWID526-3VDFE5J-3IZSHLP-KOFQKGV-7MXDMCS-TK6VYIO-HBSC46H-TJLSAAJ";
      nisha.id = "5UVRBUO-JDZKO75-KJZ6UIA-5KB4B3K-LDYY7CS-JOUZ2LP-US34QKU-BCRBDAN";
      orchard = {
        id = "PN5KMCN-RF5DBYJ-B3DCTGC-BKFGAK2-XL7PWGV-MR3FSKL-7RUIKRI-YRZ2CAS";
        addresses = ["tcp://192.168.0.175:30205" "tcp://100.64.0.2:30205" "dynamic"];
      };
    },
    syncthingFolderId ? "sync",
    # A directory with `<host>-cert.pem` and `<host>-key.pem` replaces the committed
    # certificate and the sops key; null password file selects the sops secret.
    syncthingIdentityDir ? null,
    syncthingGuiPasswordFile ? null,
  }: {
    nixos = {
      config,
      lib,
      hostName,
      secretsEnable,
      userName,
      ...
    }: let
      home = config.users.users.${userName}.home;
      peers = removeAttrs syncthingDevices [hostName];
      useSops = file: secretsEnable && file == null;
      identity = kind: "${syncthingIdentityDir}/${hostName}-${kind}.pem";
      keySecret = "syncthing/keys/${hostName}";
      passwordSecret = "syncthing/gui_password";
      sopsUnits = lib.mkIf (secretsEnable && config.sops.useSystemdActivation) {
        after = ["sops-install-secrets.service"];
        requires = ["sops-install-secrets.service"];
      };
    in {
      config =
        {
          assertions = [
            {
              assertion = syncthingDevices ? ${hostName};
              message = "syncthing: add a device ID for ${hostName} to syncthingDevices.";
            }
            {
              assertion =
                secretsEnable
                || (syncthingIdentityDir != null && syncthingGuiPasswordFile != null);
              message = "syncthing needs secretsEnable or explicit key and GUI password files.";
            }
          ];

          services.syncthing = {
            enable = true;
            user = userName;
            group = config.users.users.${userName}.group;
            dataDir = home;
            configDir = "${home}/.config/syncthing";
            openDefaultPorts = true;
            cert =
              if syncthingIdentityDir != null
              then identity "cert"
              else "${./_certs}/${hostName}.pem";
            key =
              if useSops syncthingIdentityDir
              then config.sops.secrets.${keySecret}.path
              else if syncthingIdentityDir != null
              then identity "key"
              else null;
            guiPasswordFile =
              if useSops syncthingGuiPasswordFile
              then config.sops.secrets.${passwordSecret}.path
              else syncthingGuiPasswordFile;
            settings = {
              gui.user = userName;
              options.urAccepted = -1;
              devices = lib.mapAttrs (name: device: device // {inherit name;}) peers;
              folders.${syncthingFolderId} = {
                path = "${home}/sync";
                label = syncthingFolderId;
                devices = lib.attrNames peers;
              };
            };
          };

          systemd.services = {
            syncthing = sopsUnits;
            syncthing-init = sopsUnits;
          };
        }
        // lib.optionalAttrs secretsEnable {
          sops.secrets =
            lib.optionalAttrs (useSops syncthingIdentityDir) {${keySecret} = {};}
            // lib.optionalAttrs (useSops syncthingGuiPasswordFile) {
              ${passwordSecret}.owner = userName;
            };
        };
    };
  };
  checks = {
    self,
    lib,
    pkgs,
    system,
    ...
  }:
    lib.optionalAttrs (system == "x86_64-linux") {
      pair = import ./_checks/pair.nix {inherit self pkgs;};
    };
  docs = ''
    Runs Syncthing as the user and syncs `~/sync` with the other hosts in `syncthingDevices`
    and the Syncthing instance on Orchard. Each host keeps a fixed device identity: its
    certificate is committed in `_certs/<host>.pem` and its private key is the sops secret
    `syncthing/keys/<host>`. Devices and folders set in the web UI are reverted on restart.

    The web UI listens on `127.0.0.1:8384`. Log in as the system user with the sops secret
    `syncthing/gui_password`. The Orchard instance at `syncthing.iameasytoremember.com` uses
    the same login behind Orchard login protection.
  '';
  imperativeSteps = ''
    To add a host, generate its identity and store the key in sops:

    ```bash
    syncthing generate --home="$(mktemp -d)"   # prints the device ID
    ```

    Commit `cert.pem` as `_certs/<host>.pem`, set `key.pem` as `syncthing/keys/<host>`, and
    add the device ID to `syncthingDevices`. The Orchard instance is not managed by NixOS;
    add the new device there and share the `sync` folder with it:

    ```bash
    syncthing cli --home=/config config devices add --device-id <ID> --name <host>
    syncthing cli --home=/config config folders sync devices add --device-id <ID>
    ```

    Run these in the Orchard pod as the `abc` user (`s6-setuidgid abc`).
  '';
}
