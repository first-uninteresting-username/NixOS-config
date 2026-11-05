# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "IDE";
  ids = ["IDE"];
  docs = ''
    Provides the editor-independent development tools. Select it together with one editor:
    `ide-proper` installs Zed, which needs a GPU, and `ide-lite` installs Kate, which renders
    on the CPU and suits remote desktops such as xrdp.

    `micro` is the terminal `EDITOR`. `nil`, Alejandra, `adb`, and `scrcpy` are installed for
    every editor. The `IDE` ID also selects the `wakatime` module, which reports coding time.
  '';
  state = {
    home.directories = [
      ".config/Google"
      ".local/share/Google"
      ".android"
      ".gradle"
      ".cache/Google"
      ".java"

      "Android"
      ".m2"
      ".konan"
    ];
  };
  module = _: {
    home = {pkgs, ...}: {
      programs.micro.enable = true;

      home = {
        packages = with pkgs; [
          nil
          alejandra
          android-tools
          scrcpy
        ];

        sessionVariables.EDITOR = "micro";
      };
    };
  };
}
