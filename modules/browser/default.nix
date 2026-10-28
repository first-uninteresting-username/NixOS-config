# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "browser";
  ids = ["browser"];
  state = {
    # The profile path follows the Home Manager Firefox configuration.
    home = {config}: {
      directories = [
        ".mozilla"
        config.programs.firefox.configPath
        ".cache/mozilla"
      ];
    };
  };
  module = _: {
    home = {
      pkgs,
      inputs,
      self,
      config,
      ...
    }: let
      # Firefox ships its pride logo only as a Windows icon inside omni.ja. A distinct icon
      # name keeps icon themes with their own firefox icon from overriding it.
      prideIcons =
        pkgs.runCommand "firefox-pride-icons" {
          nativeBuildInputs = [pkgs.imagemagick pkgs.unzip];
        } ''
          # omni.ja has a nonstandard zip layout that unzip reports as an error but extracts.
          unzip -q ${pkgs.firefox-unwrapped}/lib/firefox/browser/omni.ja \
            chrome/browser/content/browser/icons/pride.ico || true
          test -f chrome/browser/content/browser/icons/pride.ico
          for size in 16 32 48 64 128 256; do
            mkdir -p "$out/share/icons/hicolor/''${size}x$size/apps"
            magick chrome/browser/content/browser/icons/pride.ico -delete 0--2 \
              -resize "''${size}x$size" "$out/share/icons/hicolor/''${size}x$size/apps/firefox-pride.png"
          done
        '';
      firefox = pkgs.firefox.overrideAttrs (old: {
        buildCommand =
          old.buildCommand
          + ''
            rm -r "$out/share/icons"
            ln -s ${prideIcons}/share/icons "$out/share/icons"
            for entry in "$out"/share/applications/*.desktop; do
              sed 's/^Icon=firefox$/Icon=firefox-pride/' "$entry" > "$entry.tmp"
              rm "$entry"
              mv "$entry.tmp" "$entry"
            done
          '';
      });
    in {
      stylix.targets.firefox = {
        enable = false;
      };

      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = "firefox.desktop";
          "text/xml" = "firefox.desktop";
          "application/xhtml+xml" = "firefox.desktop";
          "application/xml" = "firefox.desktop";
          "application/vnd.mozilla.xul+xml" = "firefox.desktop";
          "x-scheme-handler/http" = "firefox.desktop";
          "x-scheme-handler/https" = "firefox.desktop";
          "x-scheme-handler/ftp" = "firefox.desktop";
          "x-scheme-handler/chrome" = "firefox.desktop";
          "x-scheme-handler/about" = "firefox.desktop";
          "x-scheme-handler/unknown" = "firefox.desktop";
        };
      };

      home.sessionVariables = {
        BROWSER = "firefox";
        DEFAULT_BROWSER = "firefox";
      };

      xdg.configFile."mimeapps.list".force = true;

      programs = {
        firefox = {
          enable = true;
          package = self.lib.mkJail {
            inherit pkgs;
            package = firefox;
            gui = true;
            network = true;
            readHostFiles = true;
            homeDirs = [
              ".mozilla"
              config.programs.firefox.configPath
              ".cache/mozilla"
            ];
            readWrite = [config.xdg.userDirs.download];
            dbusOwn = [
              "org.mozilla.firefox.*"
              "org.mpris.MediaPlayer2.firefox"
              "org.mpris.MediaPlayer2.firefox.*"
            ];
            dbusTalk = ["org.mozilla.*"];
            # Match the reference desktop's full-device Firefox policy.
            permissions = c: [(c.unsafe-add-raw-args "--dev-bind /dev /dev")];
          };

          languagePacks = [
            "en-US"
            "pl"
          ];

          policies = {
            DisableFirefoxAccounts = true;
            DisableAppUpdate = true;
            DontCheckDefaultBrowser = true;
            DisableSetDesktopBackground = true;
            DisableProfileImport = true;
            Preferences = {
              "browser.download.useDownloadDir" = true;
              "browser.download.alwaysOpenPanel" = true;
              "browser.tabs.warnOnClose" = false;
              "browser.tabs.closeWindowWithLastTab" = true;
              "browser.startup.page" = 3;
              "browser.urlbar.speculativeConnect.enabled" = false;
              "network.http.max-persistent-connections-per-server" = 10;
              "gfx.webrender.all" = true;
              "layers.acceleration.force-enabled" = true;
              "browser.search.suggest.enabled" = true;
              "browser.urlbar.suggest.searches" = true;
              "media.autoplay.default" = 1;
              "media.autoplay.blocking_policy" = 1;
              "browser.tabs.unloadOnLowMemory" = true;
              "permissions.default.desktop-notification" = 2;
              "sidebar.revamp" = true;
              "browser.toolbar.bookmarks.visibility" = "never";
            };
          };

          profiles.default = {
            id = 0;
            isDefault = true;

            search = {
              default = "ddg";
              force = true;

              engines = {
                "NixOS Packages" = {
                  urls = [{template = "https://search.nixos.org/packages?channel=unstable&query={searchTerms}";}];
                  icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [
                    "@nixpkgs"
                    "@nix"
                    "@np"
                  ];
                };
                "NixOS Options" = {
                  urls = [{template = "https://search.nixos.org/options?channel=unstable&query={searchTerms}";}];
                  icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [
                    "@no"
                    "@nixoptions"
                  ];
                };

                "bing".metaData.hidden = true;
                "amazon".metaData.hidden = true;
              };
            };

            extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
              ublock-origin
              proton-pass
              sponsorblock
              violentmonkey
              private-grammar-checker-harper
              consent-o-matic
              lichess-tools-by-siderite
            ];

            settings = {
              "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
              "general.smoothScroll" = true;
              # I love telemetry
              "datareporting.healthreport.uploadEnabled" = true;
              "toolkit.telemetry.enabled" = true;
              "sidebar.verticalTabs" = true;
              "browser.sidebar.show" = true;
              "browser.newtabpage.activity-stream.feeds.topsites" = false;
              "browser.newtabpage.activity-stream.showSearchShortcuts" = false;
              "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
              "browser.newtabpage.activity-stream.feeds.discoverystreams" = false;
              "browser.newtabpage.activity-stream.showSponsored" = false;
              "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
              "browser.ctrlTab.sortByRecentlyUsed" = true;
              "signon.rememberSignons" = false;
              "signon.autofillForms" = false;
              "browser.toolbars.bookmarks.visibility" = "never";
              "general.autoScroll" = true;
              "browser.aboutConfig.showWarning" = false;
              "browser.download.autohideButton" = false;
              "browser.ml.linkPreview.optin" = true;
              "browser.ml.chat.provider" = "https://arena.ai/agent";
              "browser.preferences.moreFromMozilla" = false;
            };
          };
        };
      };
    };
  };
  docs = ''
    Firefox runs in a sandbox with writable access to its Home Manager profile directory,
    legacy Mozilla directory, cache, and downloads. The profile directory is preserved
    across reboots when preservation is enabled. Its desktop icon uses the pride logo
    bundled with Firefox.
  '';
}
