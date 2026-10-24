# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "llama-cpp";
  ids = ["llama-cpp"];
  state = {
    home.directories = [
      ".cache/llama.cpp"
      ".cache/huggingface"
    ];
  };
  module = _: {
    home = {pkgs, ...}: {
      home.packages = with pkgs; [
        llama-cpp-vulkan
      ];
    };
  };
}
