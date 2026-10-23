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
      mktemp /var/tmp/probe-XXXXXX > /dev/null
      printf '%s\n' "$@" > "$HOME/app state/args"
      printf '%s\n' '${message}' > "$HOME/app state/message"
      readlink /proc/self/ns/net > "$HOME/app state/net"
      SCRIPT
      cat > "$out/bin/bus-probe" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      exec ${pkgs.dbus}/bin/dbus-send --session --print-reply --dest="$1" / example.Test.Ping
      SCRIPT
      cat > "$out/bin/full-read-probe" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      set -eu
      test -e "$HOME/secret"
      test -d "$HOME/.ssh"
      test "$(cat "$HOME/data-link")" = readable
      test "$(cat /srv/data/file)" = readable
      test "$(cat /mnt/file)" = readable
      test "$(cat /run/media/file)" = readable
      test -r /etc/os-release
      test -r /etc/resolv.conf
      /bin/sh -c 'test -r /etc/passwd'
      ! test -e /tmp/host-only
      ! test -e /var/tmp/host-only
      mktemp /var/tmp/probe-XXXXXX > /dev/null
      ! test -e /run/dbus/system_bus_socket
      ! test -e /nix/var/nix/daemon-socket/socket
      ! touch "$HOME/forbidden" 2>/dev/null
      ! touch /srv/data/forbidden 2>/dev/null
      ! touch /mnt/forbidden 2>/dev/null
      ! touch /run/media/forbidden 2>/dev/null
      ! printf changed > /srv/data/file 2>/dev/null
      printf saved > "$HOME/app state/broad"
      readlink /proc/self/ns/net > "$HOME/app state/broad-net"
      SCRIPT
      cat > "$out/bin/desktop-probe" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      set -eu
      test -r /lib64/jail-loader
      test "$XDG_CONFIG_HOME" = "$HOME/.config"
      case "$XDG_DATA_DIRS" in *"${pkgs.adwaita-icon-theme}/share"*) ;; *) exit 1;; esac
      case "$XDG_DATA_DIRS" in *"${pkgs.shared-mime-info}/share"*) ;; *) exit 1;; esac
      test "$ELECTRON_OZONE_PLATFORM_HINT" = auto
      echo writable > "$XDG_RUNTIME_DIR/dconf/probe"
      SCRIPT
      cat > "$out/bin/device-probe" <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      test -r /dev/jail-device
      SCRIPT
      chmod +x "$out/bin/probe" "$out/bin/bus-probe" "$out/bin/full-read-probe" \
        "$out/bin/desktop-probe" "$out/bin/device-probe"
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
  fullRead = self.lib.mkJail {
    inherit pkgs;
    package = original;
    readHostFiles = true;
    homeDirs = ["app state"];
  };
  graphicalFullRead = self.lib.mkJail {
    inherit pkgs;
    package = original;
    gui = true;
    network = true;
    readHostFiles = true;
    homeDirs = ["app state"];
    dbusTalk = ["example.Allowed"];
  };
  deviceAccess = self.lib.mkJail {
    inherit pkgs;
    package = original;
    gui = true;
    readHostFiles = true;
    permissions = c: [(c.unsafe-add-raw-args "--dev-bind /dev /dev")];
  };
  keyringAccess = self.lib.mkJail {
    inherit pkgs;
    package = original;
    gui = true;
    readHostFiles = true;
    dbusTalk = ["org.freedesktop.secrets" "org.kde.kwalletd6"];
  };
  sessionTest = pkgs.writeShellScript "jail-session-test" ''
    set -eu
    XDG_RUNTIME_DIR=$(mktemp -d)
    export XDG_RUNTIME_DIR
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    busPid=$(${pkgs.dbus}/bin/dbus-daemon --session --fork --print-pid \
      --address="$DBUS_SESSION_BUS_ADDRESS")
    mkdir -p "$XDG_RUNTIME_DIR/dconf"
    serviceNames=(
      example.Allowed example.Blocked org.freedesktop.portal.Test
      org.gtk.vfs org.gtk.vfs.Test org.freedesktop.secrets org.kde.kwalletd6
    )
    servicePids=()
    trap 'kill "''${servicePids[@]}" "$busPid"; rm -rf "$XDG_RUNTIME_DIR"' EXIT
    for name in "''${serviceNames[@]}"; do
      ${pkgs.dbus}/bin/dbus-test-tool echo --name="$name" &
      servicePids+=("$!")
      for attempt in $(seq 1 50); do
        if ${pkgs.dbus}/bin/dbus-send --session --print-reply \
          --dest=org.freedesktop.DBus /org/freedesktop/DBus \
          org.freedesktop.DBus.NameHasOwner string:"$name" | ${pkgs.gnugrep}/bin/grep -q true; then
          break
        fi
        sleep 0.1
      done
      # A denied call only proves filtering if the unfiltered service is reachable.
      ${pkgs.dbus}/bin/dbus-send --session --print-reply --dest="$name" / example.Test.Ping
    done
    for wrapper in ${graphical} ${graphicalFullRead}; do
      for name in org.freedesktop.portal.Test org.gtk.vfs org.gtk.vfs.Test; do
        "$wrapper/bin/bus-probe" "$name"
      done
      "$wrapper/bin/desktop-probe"
      test "$(cat "$XDG_RUNTIME_DIR/dconf/probe")" = writable
    done
    ${deviceAccess}/bin/device-probe
    ${keyringAccess}/bin/bus-probe org.freedesktop.secrets
    ${keyringAccess}/bin/bus-probe org.kde.kwalletd6
    ${graphical}/bin/bus-probe example.Allowed
    if ${graphical}/bin/bus-probe example.Blocked; then
      echo "blocked D-Bus name was reachable" >&2
      exit 1
    fi
    ${graphical}/bin/probe 'one argument' 'two;$(false)'
    ${graphicalFullRead}/bin/bus-probe example.Allowed
    if ${graphicalFullRead}/bin/bus-probe example.Blocked; then
      echo "blocked D-Bus name was reachable with readHostFiles" >&2
      exit 1
    fi
    ${graphicalFullRead}/bin/full-read-probe
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
      machine.succeed("mkdir -p /lib64; touch /lib64/jail-loader /dev/jail-device")
      machine.succeed("su - alice -c 'mkdir -p \"read only\" .ssh; echo visible > \"read only/input\"; touch secret'")

      machine.succeed("mkdir -p /srv/data /mnt /run/media; mount -t tmpfs tmpfs /mnt; echo readable > /srv/data/file; cp /srv/data/file /mnt/file; cp /srv/data/file /run/media/file; chown -R alice:users /srv/data /mnt /run/media; touch /tmp/host-only /var/tmp/host-only")
      machine.succeed("su - alice -c 'ln -s /srv/data/file data-link'")

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
      machine.succeed("su - alice -c '${fullRead}/bin/full-read-probe'")
      assert machine.succeed("cat '/home/alice/app state/broad-net'").strip() != host_net
      machine.succeed("su - alice -c '${sessionTest}'")
      assert machine.succeed("cat '/home/alice/app state/broad-net'").strip() == host_net
      machine.succeed("test ! -e /home/alice/forbidden; test ! -e /srv/data/forbidden; test ! -e /mnt/forbidden; test ! -e /run/media/forbidden")
      machine.fail("ls /var/tmp/probe-*")
    '';
  }
