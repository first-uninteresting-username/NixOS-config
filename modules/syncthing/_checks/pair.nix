# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Two hosts with fixed identities pair from configuration alone, sync ~/sync both ways, and
# accept the GUI login from the password file. The fixture keys are intentionally public.
{
  self,
  pkgs,
  ...
}: let
  fixtures = ./fixtures;
  passwordFile = pkgs.writeText "syncthing-gui-password" "fixture-password";
  node = name: {
    imports = [self.nixosModules.syncthing];
    _module.args.hostName = name;
    # The exported modules embed the default Home Manager user.
    home-manager.users.user.home.stateVersion = "26.11";
    users.users.user.isNormalUser = true;
    environment.systemPackages = [pkgs.curl];
  };
in
  pkgs.testers.runNixOSTest {
    name = "syncthing-pair";

    node.specialArgs = {
      secretsEnable = false;
      userName = "user";
      syncthingDevices = {
        alpha = {
          id = "ADV3VH7-KXWRRHZ-VG4YAJW-ZVH66RI-UF3ZJLB-HYFCMP3-II2YYHT-SRHOQAR";
          addresses = ["tcp://alpha:22000"];
        };
        beta = {
          id = "M7A6FFP-EPZG5CN-ALFJOYJ-GHHSIDF-A4LSNQU-QXBQSRV-7MYTLB7-IQRPKAY";
          addresses = ["tcp://beta:22000"];
        };
      };
      syncthingIdentityDir = "${fixtures}";
      syncthingGuiPasswordFile = "${passwordFile}";
    };

    nodes = {
      alpha = node "alpha";
      beta = node "beta";
    };

    testScript = ''
      start_all()
      for machine in (alpha, beta):
          machine.wait_for_unit("syncthing-init.service")

      alpha.succeed("su user -c 'echo from-alpha > ~/sync/a.txt'")
      beta.succeed("su user -c 'echo from-beta > ~/sync/b.txt'")
      beta.wait_until_succeeds("grep -qx from-alpha /home/user/sync/a.txt", timeout=180)
      alpha.wait_until_succeeds("grep -qx from-beta /home/user/sync/b.txt", timeout=180)

      gui = "http://127.0.0.1:8384/rest/noauth/auth/password"
      alpha.succeed(
          f"curl -sf -H 'Content-Type: application/json' -d '{{\"username\":\"user\",\"password\":\"fixture-password\"}}' {gui}"
      )
      alpha.fail(
          f"curl -sf -H 'Content-Type: application/json' -d '{{\"username\":\"user\",\"password\":\"wrong\"}}' {gui}"
      )
    '';
  }
