# AI usage in GNOME

Hosts selecting both `GNOME` and `agents` install ai-usagebar 1.41.0 and its
GNOME Shell extension. This includes armin and victim, without adding it to the
graphical installer. Both packages build from the same SHA-256-pinned release
archive; the checked-in upstream Cargo.lock pins Rust dependencies. No installer
script runs at login. The extension supports GNOME Shell 45–50; evaluation rejects
other versions until compatibility is reviewed.

The top bar shows Codex usage percentages. Its dropdown includes available quota
windows and reset times. Refresh runs every 300 seconds to avoid aggressive API
polling. Quota warnings use desktop notifications at 97% by default.

The initial configuration enables Codex, which the agents module already installs.
It reuses `~/.codex/auth.json` from `codex login`. Authentication and live usage
cannot be verified during a build.

## Local settings and credentials

On first activation, Home Manager creates `~/.config/ai-usagebar/config.toml` with
mode 0600. Later rebuilds preserve edits. The directory persists when preservation
is enabled; the agents module already preserves `.codex`. Caches may be regenerated.

Use `ai-usagebar-tui` and its Settings screen, or edit this local TOML file, to
enable other providers and adjust `[notifications]`. For example, Claude uses
`[anthropic] enabled = true` and requires its own CLI login. Keep API keys in the
local file, never in Nix configuration or this repository. Protect and persist
any additional provider credential files separately.

Use `gnome-extensions prefs ai-usagebar@akitaonrails.github.io` to choose top bar
providers and display settings. Other enabled providers appear in the dropdown
even if they have no dedicated top bar selector. Home Manager supplies the binary
path, initial Codex selector, and 300-second interval on each activation.

## Verify on the desktop

1. Build and activate this configuration, then log out and back in on Wayland.
2. Run `gnome-extensions info ai-usagebar@akitaonrails.github.io`; confirm it is enabled.
3. Open the indicator and check percentages and reset times against your provider.
   `ai-usagebar usage --json` helps diagnose authentication errors; avoid sharing
   its output without reviewing account details.
4. Check Refresh now, Settings, and Open TUI (which uses Ptyxis).
5. Rebuild and reboot, then repeat the indicator and dropdown check. Confirm local
   configuration and Codex login survive. Warnings require a real threshold crossing.

The package smoke check covers both executables and the compiled extension schema.
It does not test a live GNOME session or contact provider APIs.
