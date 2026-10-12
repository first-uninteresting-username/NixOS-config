# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  withSystem,
  lib,
  ...
}: let
  makeCheck = pkgs: regression:
    pkgs.testers.runNixOSTest {
      name = "printing-discovery${lib.optionalString regression "-regression"}";

      nodes = {
        client = {lib, ...}: {
          imports = [
            self.nixosModules.user
            self.nixosModules.home-manager
            self.nixosModules.preservation
            self.nixosModules.printing
          ];
          custom.user = {
            enable = true;
            name = "testuser";
            password = "testuser";
          };
          environment.systemPackages = [pkgs.cups pkgs.curl];

          # A local file backend exercises job delivery without a physical printer.
          services.printing.extraFilesConf = "FileDevice Yes";
          environment.etc."checks-printer.ppd".text = ''
            *PPD-Adobe: "4.3"
            *FormatVersion: "4.3"
            *FileVersion: "1.0"
            *LanguageVersion: English
            *LanguageEncoding: ISOLatin1
            *PCFileName: "CHECKS.PPD"
            *Manufacturer: "Checks"
            *Product: "(Checks printer)"
            *ModelName: "Checks printer"
            *NickName: "Checks printer"
            *ShortNickName: "Checks printer"
            *PSVersion: "(3010.000) 0"
            *LanguageLevel: "3"
            *ColorDevice: False
            *DefaultColorSpace: Gray
            *OpenUI *PageSize/Page Size: PickOne
            *DefaultPageSize: A4
            *PageSize A4/A4: "<</PageSize[595 842]>>setpagedevice"
            *CloseUI: *PageSize
            *OpenUI *PageRegion/Page Region: PickOne
            *DefaultPageRegion: A4
            *PageRegion A4/A4: "<</PageSize[595 842]>>setpagedevice"
            *CloseUI: *PageRegion
            *DefaultImageableArea: A4
            *ImageableArea A4/A4: "0 0 595 842"
            *DefaultPaperDimension: A4
            *PaperDimension A4/A4: "595 842"
          '';

          # A representative regression: multicast discovery responses are blocked.
          services.avahi.openFirewall = lib.mkIf regression (lib.mkForce false);
        };

        # The desktop discovers this independently advertised network printer.
        printer = _: {
          environment.systemPackages = [pkgs.netcat-openbsd];
          services.avahi = {
            enable = true;
            publish = {
              enable = true;
              addresses = true;
            };
            extraServiceFiles.printer = ''
              <?xml version="1.0" standalone="no"?>
              <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
              <service-group>
                <name>checks-printer</name>
                <service>
                  <type>_ipp._tcp</type>
                  <port>8631</port>
                  <txt-record>rp=printers/fixture</txt-record>
                  <txt-record>pdl=application/pdf</txt-record>
                </service>
              </service-group>
            '';
          };
        };
      };

      testScript = ''
        import time

        start_all()
        client.wait_for_unit("multi-user.target")
        printer.wait_for_unit("avahi-daemon.service")
        client.wait_for_unit("avahi-daemon.service")
        client.wait_for_unit("cups-browsed.service")

        # Resolve a real DNS-SD response, including its hostname, address and port.
        deadline = time.monotonic() + 60
        while True:
            discovery_status, discovery_output = client.execute(
                "avahi-browse --resolve --terminate --parsable _ipp._tcp", timeout=15
            )
            assert discovery_status == 0, discovery_output
            records = discovery_output.splitlines()
            resolved = [line.split(";") for line in records if line.startswith("=")]
            if any(
                len(row) >= 10 and row[3:7] == [
                    "checks-printer", "_ipp._tcp", "local", "printer.local"
                ] and row[8] == "8631"
                for row in resolved
            ):
                break
            assert time.monotonic() < deadline, (
                "CHECKS_V2_REGRESSION:printing-mdns-discovery " + discovery_output
            )
            time.sleep(1)
        printer_ip = client.succeed("getent ahostsv4 printer").split()[0]
        assert any(
            row[2] == "IPv4" and row[3] == "checks-printer"
            and row[6] == "printer.local" and row[7] == printer_ip
            and row[8] == "8631" and "rp=printers/fixture" in row[9]
            for row in resolved
        ), records
        client.wait_until_succeeds("getent ahostsv4 printer.local", timeout=60)
        addresses = client.succeed("getent ahostsv4 printer.local").splitlines()
        assert any(line.split()[0] == printer_ip for line in addresses), addresses

        # The local scheduler delivers a job, while the peer cannot access CUPS.
        client.succeed("curl -fsS --max-time 10 http://127.0.0.1:631/ > /dev/null")
        client.wait_for_unit("cups.service")
        client.succeed(
            "lpadmin -p fixture -E -v file:/var/spool/cups/fixture-output "
            "-P /etc/checks-printer.ppd"
        )
        client.succeed("printf checks-v2-print | lp -d fixture -o raw")
        client.wait_until_succeeds(
            "test \"$(cat /var/spool/cups/fixture-output)\" = checks-v2-print",
            timeout=60,
        )
        client_ip = printer.succeed("getent ahostsv4 client").split()[0]
        client.fail(f"curl -fsS --max-time 5 http://{client_ip}:631/")
        printer.fail("nc -z -w 3 client 631")
      '';
    };
in {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      printing-discovery = makeCheck pkgs false;
    };
  };

  flake.regressionChecks.x86_64-linux.printing-discovery =
    withSystem "x86_64-linux" ({pkgs, ...}: makeCheck pkgs true);
}
