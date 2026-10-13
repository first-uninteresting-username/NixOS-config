# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  withSystem,
  ...
}: let
  mkCheck = pkgs: broken:
    pkgs.testers.runNixOSTest {
      name = "gnome-session";
      requiredFeatures.kvm = true;

      nodes.machine = {...}: {
        imports = [
          self.nixosModules.DE
          self.nixosModules.user
          self.nixosModules.stylix
          self.nixosModules.preservation
          self.nixosModules.home-manager
        ];

        custom = {
          user = {
            enable = true;
            name = "testuser";
            password = "testuser";
          };
          preservation.enable = false;
          stylix.enable = true;
          DE = {
            enable = true;
            name = "gnome";
          };
        };

        services.displayManager.autoLogin = {
          enable = true;
          user = "testuser";
        };
        services.displayManager.gdm.autoSuspend = false;

        # Shell's evaluation API lets the test observe a real application window.
        systemd.user.services."org.gnome.Shell@".serviceConfig.ExecStart = [
          ""
          "${pkgs.gnome-shell}/bin/gnome-shell --unsafe-mode"
        ];

        home-manager.extraSpecialArgs = {
          inherit self;
          inherit (self) inputs;
        };
        home-manager.users.testuser = {lib, ...}: {
          home.activation = lib.optionalAttrs broken {
            seedHexecuteGestures = lib.mkForce (lib.hm.dag.entryAfter ["writeBoundary"] "true");
          };
        };

        virtualisation = {
          cores = 2;
          memorySize = 4096;
        };
      };

      testScript = ''
        import shlex

        def as_user(command):
            return (
                "runuser -u testuser -- env "
                "XDG_RUNTIME_DIR=/run/user/1000 "
                "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
                "WAYLAND_DISPLAY=wayland-0 bash -lc " + shlex.quote(command)
            )

        def shell_eval(expression):
            return as_user(
                "gdbus call --session --dest org.gnome.Shell "
                "--object-path /org/gnome/Shell --method org.gnome.Shell.Eval "
                + shlex.quote(expression)
            )

        with subtest("Home Manager activates the repository GNOME configuration"):
            machine.wait_for_unit("home-manager-testuser.service")
            status, output = machine.execute(
                "test -s /home/testuser/.config/hexecute/gestures.json"
            )
            assert status == 0, (
                "CHECKS_V2_REGRESSION:gnome-home-manager-gestures: " + output
            )
            machine.succeed(
                "test $(stat -c %U /home/testuser/.config/hexecute/gestures.json) = testuser"
            )

        with subtest("GDM starts a usable Wayland user session"):
            machine.wait_for_unit("display-manager.service")
            machine.wait_for_file("/run/user/1000/wayland-0")
            machine.wait_for_unit("graphical-session.target", "testuser")
            machine.wait_until_succeeds(shell_eval("Main.layoutManager._startingUp") +
                                        " | grep -q 'true,..false'")
            machine.succeed(
                "loginctl list-sessions --no-legend | "
                "awk '$3 == \"testuser\" { print $1 }' | "
                "xargs -r -I{} loginctl show-session {} -p Type --value | grep -qx wayland"
            )

        with subtest("The repository terminal opens in GNOME"):
            machine.send_key("esc")
            machine.succeed(as_user("gapplication launch org.gnome.Ptyxis"))
            machine.wait_until_succeeds(shell_eval(
                "global.get_window_actors().some(a => "
                "a.meta_window.get_wm_class() === 'org.gnome.Ptyxis')"
            ) + " | grep -q 'true,..true'")

            machine.screenshot("gnome-session")
      '';
    };
in {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      gnome-session = mkCheck pkgs false;
    };
  };

  flake.regressionChecks.x86_64-linux.gnome-session =
    withSystem "x86_64-linux" ({pkgs, ...}: mkCheck pkgs true);
}
