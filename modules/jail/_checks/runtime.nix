# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  self,
  pkgs,
}: let
  # A second executable and absolute desktop/service launchers exercise wrapper bypasses.
  original = pkgs.lib.makeOverridable ({message ? "original"}:
    pkgs.runCommand "jail-probe" {
      outputs = ["out" "bin" "man"];
      meta = {
        mainProgram = "probe";
        outputsToInstall = ["out" "bin" "man"];
      };
    } ''
      mkdir -p "$out/bin" "$out/share/applications" "$out/share/dbus-1/services"
      cat > "$out/bin/probe" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      set -eu
      test "$(cat "$HOME/read only/input")" = visible
      ! test -e "$HOME/secret"
      ! test -e "$HOME/.ssh"
      ! test -e /run/dbus/system_bus_socket
      ! touch "$HOME/read only/forbidden" 2>/dev/null
      printf '%s\n' "$@" > "$HOME/app state/args"
      printf '%s\n' '${message}' > "$HOME/app state/message"
      readlink /proc/self/ns/net > "$HOME/app state/net"
      SCRIPT
      cat > "$out/bin/bus-probe" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      exec ${pkgs.dbus}/bin/dbus-send --session --print-reply --dest="$1" / example.Test.Ping
      SCRIPT
      chmod +x "$out/bin/probe" "$out/bin/bus-probe"
      ln -s probe "$out/bin/alias"
      ln -s probe "$out/bin/.hidden"
      cat > "$out/share/applications/probe.desktop" <<DESKTOP
      [Desktop Entry]
      Name=Probe
      Type=Application
      Exec=$out/bin/probe %U
      TryExec=$out/bin/alias
      Icon=$out/share/icon.png
      Actions=Alias;
      [Desktop Action Alias]
      Name=Alias
      Exec=$out/bin/alias %U
      DESKTOP
      cat > "$out/share/dbus-1/services/probe.service" <<SERVICE
      [D-BUS Service]
      Name=example.Probe
      Exec=$out/bin/alias
      SERVICE
      mkdir -p "$bin" "$man/share/man/man1"
      echo manual > "$man/share/man/man1/probe.1"
      mv "$out/bin" "$bin/executables"
      ln -s executables "$bin/bin"
      substituteInPlace "$out/share/applications/probe.desktop" \
        "$out/share/dbus-1/services/probe.service" \
        --replace-fail "$out/bin/" "$bin/bin/"
      mv "$out/share/applications" "$out/desktops"
      ln -s ../desktops "$out/share/applications"
    '') {};
  jailed = self.lib.mkJail {
    inherit pkgs;
    package = original;
    homeDirs = ["app state"];
    readOnly = ["/home/alice/read only"];
    readWrite = ["/home/alice/missing"];
  };
  overridden = jailed.override {message = "overridden";};
  online = self.lib.mkJail {
    inherit pkgs;
    package = original;
    network = true;
    homeDirs = ["app state"];
    readOnly = ["/home/alice/read only"];
  };
  graphical = self.lib.mkJail {
    inherit pkgs;
    package = original;
    gui = true;
    homeDirs = ["app state"];
    readOnly = ["/home/alice/read only"];
    dbusTalk = ["example.Allowed"];
  };
  sessionTest = pkgs.writeShellScript "jail-session-test" ''
    set -eu
    XDG_RUNTIME_DIR=$(mktemp -d)
    export XDG_RUNTIME_DIR
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    busPid=$(${pkgs.dbus}/bin/dbus-daemon --session --fork --print-pid \
      --address="$DBUS_SESSION_BUS_ADDRESS")
    ${pkgs.dbus}/bin/dbus-test-tool echo --name=example.Allowed &
    allowedPid=$!
    ${pkgs.dbus}/bin/dbus-test-tool echo --name=example.Blocked &
    blockedPid=$!
    trap 'kill "$allowedPid" "$blockedPid" "$busPid"; rm -rf "$XDG_RUNTIME_DIR"' EXIT
    for name in example.Allowed example.Blocked; do
      for attempt in $(seq 1 50); do
        if ${pkgs.dbus}/bin/dbus-send --session --print-reply \
          --dest=org.freedesktop.DBus /org/freedesktop/DBus \
          org.freedesktop.DBus.NameHasOwner string:"$name" | ${pkgs.gnugrep}/bin/grep -q true; then
          break
        fi
        sleep 0.1
      done
    done
    ${graphical}/bin/bus-probe example.Allowed
    if ${graphical}/bin/bus-probe example.Blocked; then
      echo "blocked D-Bus name was reachable" >&2
      exit 1
    fi
    ${graphical}/bin/probe 'one argument' 'two;$(false)'
  '';
in
  pkgs.testers.runNixOSTest {
    name = "jail";
    nodes.machine = _: {
      users.users.alice = {
        isNormalUser = true;
        password = "public-test-password";
      };
      environment.systemPackages = [(pkgs.lib.getBin jailed)];
    };
    testScript = ''
      import shlex

      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("su - alice -c 'mkdir -p \"read only\" .ssh; echo visible > \"read only/input\"; touch secret'")

      def run(binary):
          command = shlex.quote(binary) + " 'one argument' 'two;$(false)'"
          machine.succeed("su - alice -c " + shlex.quote(command))
          assert machine.succeed("cat '/home/alice/app state/args'") == "one argument\ntwo;$(false)\n"

      run("${pkgs.lib.getExe jailed}")
      run("/run/current-system/sw/bin/probe")
      machine.succeed("test -s ${jailed.man}/share/man/man1/probe.1")
      host_net = machine.succeed("readlink /proc/1/ns/net").strip()
      for name in ["probe", "alias", ".hidden"]:
          run("${jailed}/bin/" + name)
          assert machine.succeed("cat '/home/alice/app state/net'").strip() != host_net
      assert machine.succeed("cat '/home/alice/app state/message'").strip() == "original"
      run("${overridden}/bin/probe")
      assert machine.succeed("cat '/home/alice/app state/message'").strip() == "overridden"
      run("${online}/bin/probe")
      assert machine.succeed("cat '/home/alice/app state/net'").strip() == host_net

      desktop = machine.succeed("cat ${jailed}/share/applications/probe.desktop")
      assert "Exec=${jailed}/bin/probe %U" in desktop
      assert "TryExec=${jailed}/bin/alias" in desktop
      assert "Exec=${jailed}/bin/alias %U" in desktop
      assert "Icon=${original}/share/icon.png" in desktop
      service = machine.succeed("cat ${jailed}/share/dbus-1/services/probe.service")
      assert "Exec=${jailed}/bin/alias" in service
      run(service.split("Exec=", 1)[1].strip())
      machine.succeed("test ! -e '/home/alice/read only/forbidden'")
      machine.fail("su - alice -c 'XDG_RUNTIME_DIR=/missing ${graphical}/bin/bus-probe example.Allowed'")
      machine.succeed("su - alice -c '${sessionTest}'")
    '';
  }
