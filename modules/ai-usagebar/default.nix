# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "ai-usagebar";
  ids = ["GNOME" "agents"];
  packages = import ./_packages.nix;
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist".users.${userName}.directories = [".config/ai-usagebar"];
      };
    };
    home = {
      lib,
      packages,
      ...
    }: {
      home.packages = [packages.default];
      programs.gnome-shell = {
        enable = true;
        extensions = [{package = packages.extension;}];
      };
      dconf.settings."org/gnome/shell/extensions/ai-usagebar" = {
        binary-path = lib.getExe packages.default;
        vendor = "anthropic";
        refresh-interval = 300;
      };
      # Keep the file writable for local API keys and upstream's Settings UI.
      home.activation.seedAiUsagebar = lib.hm.dag.entryAfter ["writeBoundary"] ''
        configDir="$HOME/.config/ai-usagebar"
        configFile="$configDir/config.toml"
        if [ ! -e "$configFile" ]; then
          install -d -m700 "$configDir"
          (umask 077; cat > "$configFile" <<'TOML'
        [ui]
        primary = "anthropic"
        [openai]
        enabled = false
        [anthropic]
        enabled = true
        [zai]
        enabled = false
        [openrouter]
        enabled = false
        [notifications]
        enabled = true
        threshold = 97
        TOML
          )
        fi
      '';
    };
  };
  checks = {
    pkgs,
    packages,
    ...
  }: {
    default = pkgs.runCommand "ai-usagebar-smoke" {} ''
      export HOME="$TMPDIR"
      ${packages.default}/bin/ai-usagebar --version > version.txt
      grep -F '${packages.default.version}' version.txt
      ${packages.default}/bin/ai-usagebar-tui --help > help.txt
      test -s help.txt
      extensionDir=${packages.extension}/share/gnome-shell/extensions/${packages.extension.extensionUuid}
      test -s "$extensionDir/schemas/gschemas.compiled"
      test -s "$extensionDir/extension.js"
      touch "$out"
    '';
  };
}
