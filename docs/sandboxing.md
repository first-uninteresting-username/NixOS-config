# Application sandboxes

`self.lib.mkJail` wraps a package with [jail.nix][jail-nix] and Bubblewrap.
The shared helper follows the per-application permission model in
[csd4ni3l's configuration][reference], with broader desktop compatibility mounts.
Application modules apply their policies directly, including in standalone Home Manager.
No extra host ID enables sandboxing.

## Use mkJail

```nix
self.lib.mkJail {
  inherit pkgs;
  package = pkgs.example;
  gui = true;
  network = true;
  homeDirs = [".config/example" ".local/share/example" ".cache/example"];
  readWrite = [config.xdg.userDirs.download];
  readOnly = ["/media/reference"];
  dbusOwn = ["org.example.App" "org.example.App.*"];
}
```

Request `self` explicitly in the module section using the helper. `package` and `pkgs`
are required. All other fields default to `false`, empty lists, or an empty permission
function. The wrapper preserves package metadata, version, extra outputs, and passthru
attributes. Its `override` method rewraps the customized package, so Home Manager's
Firefox policies remain inside the jail. `unjailed` exposes the original package for
inspection; use `override` before wrapping for other package customizations.

Every executable in `bin`, including aliases and hidden executables, receives a wrapper.
Absolute `Exec` and `TryExec` references to that package's `bin` in desktop files and
D-Bus services point to the wrapper. Desktop action entries receive the same rewrite;
icons and other assets retain their original paths. A launcher that directly invokes
another package or an executable outside `bin` needs an application-specific override.

| Field | Effect |
| --- | --- |
| `gui` | Grants Wayland, GPU, audio, fonts, theme configuration, portal file access, notifications, and filtered session D-Bus access. |
| `network` | Shares the host network and supplies DNS, TLS certificates, and hostname configuration. |
| `homeDirs` | Creates and mounts writable home-relative directories before launch. Use these for persistent application settings and caches. |
| `readOnly` | Mounts existing absolute paths read only. Missing paths are skipped. |
| `readWrite` | Mounts existing absolute paths writable. Missing paths are skipped. |
| `dbusOwn` | Adds session bus names the GUI app may own. |
| `dbusTalk` | Adds session bus names the GUI app may contact. |
| `permissions` | Accepts a function from jail.nix combinators to extra permissions, applied after the shared defaults. |

`homeDirs` accepts directories, not files. Paths must be relative to home and cannot
contain empty components, `.` or `..`. Paths containing spaces are supported. `readOnly` and
`readWrite` do not create paths. The jail starts in an empty home and private `/tmp`;
unmounted application state disappears when the app exits. Existing preservation rules
retain mounted settings across reboots; `mkJail` does not add preservation rules.

For extra capabilities, use the upstream combinators:

```nix
permissions = c: [
  c.fido-token
  # Only if the application requires X11; this weakens isolation between windows.
  c.unsafe-x11
];
```

GUI mode expects a graphical session with `XDG_RUNTIME_DIR` and a session bus at
`$XDG_RUNTIME_DIR/bus`. It uses
Wayland by default. CLI mode does not require a graphical session. Neither mode exposes
the host system bus, SSH agent, Nix daemon, or home directory wholesale.

## Current application policies

| Applications | Network | Writable user data |
| --- | --- | --- |
| Firefox | Yes | Mozilla profile/cache and Downloads. |
| Slick | Yes | Slick settings/cache and Downloads; also allows the Secret Service for login. |
| Flow Desktop | Yes | Flow Beta settings/data/cache and Downloads. |
| Inkscape | No | Inkscape settings/cache, Documents, Downloads, and Pictures. |
| Papers, File Roller, Gradia, Text Editor, Loupe, Rnote | No | Each app's settings/data/cache, Documents, Downloads, Pictures, and Videos. |

Other paths can be selected through a portal file chooser when the application supports
it. Firefox cannot directly upload files from arbitrary project directories; use the
portal chooser or copy them into Downloads. Portal access is user-mediated and can grant
additional files beyond the static mounts.

This is the first rollout for [issue #570][issue], not complete coverage of the desktop.
Steam/nix-crab, game launchers, development tools and agents, remote desktop, hardware
utilities, and remaining GNOME apps still run with their existing permissions. Their
integration needs separate policies for game saves, project tools, credentials, devices,
and host services. Adding a jail around an agent while granting all of home and its
sockets would provide little useful file isolation.

## Boundaries and verification

Every jail hides unmounted home files and separates user, PID, IPC, UTS, and cgroup
namespaces. Network access is isolated unless explicitly enabled. GUI applications can
use audio capture through the exposed sound services; those sockets are not playback-only.
The entire Nix store and system profile are readable for compatibility. Do not put
secrets in the Nix store. Applications with network access can reach the LAN too.
There is no seccomp filter or per-destination network filter. Portals and explicitly
allowed D-Bus services retain their own authority; approve requests accordingly.
X11, when explicitly requested, permits interaction with other X11 clients.

The `jail` VM check exercises hidden home files, read-only mounts, writable state,
argument preservation, offline and online network namespaces, aliases, hidden
executables, package overrides, symlinked package directories, desktop/service launcher
rewriting, and allowed versus blocked D-Bus calls:

```bash
nix build -L .#checks.x86_64-linux.jail
```

The check uses synthetic applications and does not prove every real GUI application
works. Check file dialogs, audio, GPU rendering, login, and saved state in a real desktop
session after building a configuration. Building or evaluating this branch does not
activate it.

[jail-nix]: https://git.sr.ht/~alexdavid/jail.nix
[reference]: https://github.com/csd4ni3l/nixos-config/blob/main/docs/SANDBOXING.md
[issue]: https://github.com/first-uninteresting-username/NixOS-config/issues/570
