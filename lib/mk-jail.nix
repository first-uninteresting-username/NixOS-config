# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs}: args @ {
  pkgs,
  package,
  gui ? false,
  network ? false,
  readHostFiles ? false,
  homeDirs ? [],
  readOnly ? [],
  readWrite ? [],
  dbusOwn ? [],
  dbusTalk ? [],
  permissions ? _: [],
}: let
  inherit (pkgs) lib;
  mkJail = import ./mk-jail.nix {inherit inputs;};
  jail = inputs.jail-nix.lib.extend {
    inherit pkgs;
    basePermissions = c:
      if readHostFiles
      then [
        (c.readonly "/")
        # Preserve the host's symlinks; mounting /bin/sh over them would fail.
        (c.unsafe-add-raw-args "--proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --clearenv")
        (c.fwd-env "HOME")
        (c.try-fwd-env "LANG")
        (c.try-fwd-env "TERM")
        (c.add-runtime ''
          if [ -d /nix/var/nix/daemon-socket ]; then
            RUNTIME_ARGS+=(--tmpfs /nix/var/nix/daemon-socket)
          fi
        '')
      ]
      # The whole store is public on these hosts and avoids closure walks at startup.
      else [c.base c.fake-passwd (c.readonly "/nix/store")];
  };
  c = jail.combinators;
  binaryPackage = lib.getBin package;
  homePath = path: c.noescape ''"$HOME"/${lib.escapeShellArg path}'';
  validHomeDir = path:
    builtins.isString path
    && path != ""
    && !lib.hasPrefix "/" path
    && builtins.all (part: part != ".." && part != "." && part != "") (lib.splitString "/" path);
  desktopPermissions =
    [
      # jail.nix's proxy mounts the standard desktop session socket.
      (c.add-runtime ''
        if [ ! -S "''${XDG_RUNTIME_DIR-}/bus" ]; then
          # Upstream registers its cleanup trap before the proxy exists.
          trap - EXIT
          echo "mkJail: GUI requires a session bus at XDG_RUNTIME_DIR/bus" >&2
          exit 1
        fi
      '')
      c.pulse
      c.pipewire
      (
        if readHostFiles
        then c.compose []
        else c.try-readonly "/etc/fonts"
      )
      (c.try-readonly "/sys/dev/char")
      (c.try-readonly "/sys/devices")
      (c.try-readonly "/run/opengl-driver")
      (c.try-readonly "/run/opengl-driver-32")
      (c.unsafe-add-raw-args ''--dev-bind-try /dev/dri /dev/dri'')
      (c.unsafe-add-raw-args
        ''--ro-bind-try "$XDG_RUNTIME_DIR/''${WAYLAND_DISPLAY:-wayland-0}" "$XDG_RUNTIME_DIR/''${WAYLAND_DISPLAY:-wayland-0}"'')
      (c.unsafe-add-raw-args
        ''--bind-try "$XDG_RUNTIME_DIR/doc" "$XDG_RUNTIME_DIR/doc"'')
      (c.unsafe-add-raw-args
        ''--ro-bind-try "$XDG_RUNTIME_DIR/dconf" "$XDG_RUNTIME_DIR/dconf"'')
      (c.dbus {
        own = dbusOwn;
        talk =
          [
            "org.freedesktop.portal.Desktop"
            "org.freedesktop.portal.Documents"
            "org.freedesktop.Notifications"
            "org.a11y.Bus"
            "ca.desrt.dconf"
          ]
          ++ dbusTalk;
      })
      (c.readonly-paths-from-var "XDG_DATA_DIRS" ":")
      (c.readonly-paths-from-var "XCURSOR_PATH" ":")
    ]
    ++ lib.optionals (!readHostFiles) (map (path: c.try-readonly (homePath path)) [
      ".config/gtk-2.0"
      ".config/gtk-3.0"
      ".config/gtk-4.0"
      ".config/fontconfig"
      ".config/dconf"
    ]);
  wrapped = jail "${lib.getName package}-jail" package (
    lib.optionals (!readHostFiles) [
      (c.try-readonly "/etc/os-release")
      (c.try-readonly "/run/current-system/sw")
      (c.try-readonly "/etc/profiles")
      (c.try-readonly "/etc/static/profiles")
      c.time-zone
    ]
    ++ lib.optionals readHostFiles [
      # /run remains private, but these public profiles and mounted drives are readable.
      (c.try-readonly "/run/current-system/sw")
      (c.try-readonly "/run/media")
    ]
    ++ map c.try-fwd-env ["PATH" "USER" "LOGNAME" "SHELL" "LOCALE_ARCHIVE"]
    ++ lib.optionals gui desktopPermissions
    ++ lib.optionals gui (map c.try-fwd-env [
      "WAYLAND_DISPLAY"
      "XDG_RUNTIME_DIR"
      "XDG_SESSION_TYPE"
      "XDG_DATA_DIRS"
      "XCURSOR_PATH"
      "XCURSOR_THEME"
      "XCURSOR_SIZE"
      "GTK_THEME"
      "GDK_BACKEND"
      "QT_QPA_PLATFORM"
      "QT_QPA_PLATFORMTHEME"
      "QT_STYLE_OVERRIDE"
    ])
    ++ lib.optionals network (
      if readHostFiles
      then [
        (c.share-ns "net")
        (c.try-readonly "/run/systemd/resolve")
        (c.try-readonly "/run/NetworkManager/resolv.conf")
      ]
      else [c.network]
    )
    ++ lib.concatMap (path: [
      (c.add-runtime ''mkdir -p -- ${(homePath path)._noescape}'')
      (c.readwrite (homePath path))
    ])
    homeDirs
    ++ map c.try-readonly readOnly
    ++ map c.try-readwrite readWrite
    ++ permissions c
    ++ [
      # The same script is copied to each executable, preserving aliases and arguments.
      (state: state // {entry = ''"${binaryPackage}/bin/$(basename -- "$0")"'';})
    ]
  );
  result = pkgs.symlinkJoin {
    name = "${lib.getName package}-jailed-${lib.getVersion package}";
    paths = lib.unique [package binaryPackage];
    inherit (package) meta;
    version = lib.getVersion package;
    passthru = (package.passthru or {}) // {unjailed = package;};
    nativeBuildInputs = [pkgs.python3];
    postBuild = ''
      # Materialize mutable directories when the package uses directory symlinks.
      for directory in bin share share/applications share/dbus-1 share/dbus-1/services; do
        if [ -L "$out/$directory" ] && [ -d "$out/$directory" ]; then
          target=$(readlink -f "$out/$directory")
          rm "$out/$directory"
          mkdir -p "$out/$directory"
          cp -rs "$target"/. "$out/$directory/"
        fi
      done
      # Replace all entry points, including aliases, without changing the input package.
      shopt -s dotglob nullglob
      for binary in "$out"/bin/*; do
        [ -x "$binary" ] && [ ! -d "$binary" ] || continue
        rm "$binary"
        cp ${wrapped}/bin/${lib.getName package}-jail "$binary"
      done
      # Absolute launchers must reach the jail too. Keep icons and other asset paths intact.
      python3 - "$out" ${lib.escapeShellArgs (map toString [package binaryPackage])} <<'PYTHON'
      import os
      import pathlib
      import sys

      out, *originals = sys.argv[1:]

      def rewrite(line):
          for original in originals:
              line = line.replace(original + "/bin/", out + "/bin/")
          return line
      for directory, suffix, keys in [
          ("share/applications", ".desktop", ("Exec=", "TryExec=")),
          ("share/dbus-1/services", ".service", ("Exec=",)),
      ]:
          for path in pathlib.Path(out, directory).glob("*" + suffix):
              text = path.read_text()
              updated = "".join(
                  rewrite(line)
                  if line.startswith(keys) else line
                  for line in text.splitlines(keepends=True)
              )
              path.unlink()
              path.write_text(updated)
              os.chmod(path, 0o444)
      PYTHON
    '';
  };
  finalPackage =
    result
    // lib.genAttrs (builtins.filter (output: output != "out" && output != "bin") (package.outputs or []))
    (output: package.${output})
    // lib.optionalAttrs (package ? bin) {bin = finalPackage;}
    // lib.optionalAttrs (package ? override) {
      # Home Manager inspects the argument metadata before injecting Firefox policies.
      override =
        lib.setFunctionArgs
        (overrides: mkJail (args // {package = package.override overrides;}))
        (lib.functionArgs package.override);
    };
in
  assert lib.assertMsg (builtins.all validHomeDir homeDirs)
  "mkJail: homeDirs must contain nonempty home-relative directories without . or .."; finalPackage
