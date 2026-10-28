# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "stremio";
  ids = ["stremio"];
  state = {
    home.directories = [
      # WebKit storage: account login, local add-ons and library.
      ".local/share/stremio"
      # Streaming server settings and cache.
      ".stremio-server"
    ];
  };
  module = {stremioAddonUrl ? "https://aiostreams.iameasytoremember.com/stremio/manifest.json"}: {
    home = {
      lib,
      pkgs,
      ...
    }: let
      stremio = pkgs.stremio-linux-shell;
      # Stremio installs add-ons from deep links that replace the https:// scheme.
      installLink = "stremio://" + lib.removePrefix "https://" stremioAddonUrl;
    in {
      home.packages = [stremio];

      xdg.desktopEntries."stremio-install-addon" = {
        name = "Install AIOStreams in Stremio";
        comment = "Open the AIOStreams add-on install prompt in Stremio";
        exec = "${lib.getExe stremio} ${installLink}";
        icon = "com.stremio.Stremio";
        terminal = false;
        type = "Application";
        categories = ["AudioVideo" "Video"];
      };

      # The AIOStreams configure page installs through stremio:// links.
      xdg.mimeApps = {
        enable = true;
        defaultApplications."x-scheme-handler/stremio" = "com.stremio.Stremio.desktop";
      };
    };
  };
  docs = ''
    Installs the Stremio desktop client (`stremio-linux-shell`) and registers it for
    `stremio://` links. The `stremio` host ID enables it; victim and armin select it.

    Stremio has no declarative add-on configuration: add-ons belong to the Stremio account
    (or to the local WebKit storage when signed out). The module therefore adds an
    **Install AIOStreams in Stremio** launcher that opens the install prompt for
    `stremioAddonUrl`, by default the self-hosted AIOStreams instance on Orchard.

    WebKit storage in `~/.local/share/stremio` and streaming-server data in
    `~/.stremio-server` persist when preservation is enabled.
  '';
  imperativeSteps = ''
    Set up AIOStreams once and install it into Stremio:

    1. Open the **Install AIOStreams in Stremio** launcher and select **Configure**, or visit
       <https://aiostreams.iameasytoremember.com/stremio/configure>.
    2. Sign in with the AIOStreams credentials, choose add-ons and services, and save.
    3. Select **Install** on the configure page. The `stremio://` link opens Stremio.

    Sign in to Stremio first so the add-on syncs to every device on the account.
  '';
}
