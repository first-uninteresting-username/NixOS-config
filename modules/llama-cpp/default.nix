# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "llama-cpp";
  ids = ["llama-cpp"];
  module = _: {
    nixos = {
      lib,
      userName,
      preservationEnable,
      ...
    }: {
      preservation.preserveAt = lib.mkIf preservationEnable {
        "/persist" = {
          users.${userName} = {
            directories = [
              ".cache/llama.cpp"
              ".cache/huggingface"
            ];
          };
        };
      };
    };
    home = {pkgs, ...}: {
      home.packages = with pkgs; [
        llama-cpp-vulkan
      ];
    };
  };
}
