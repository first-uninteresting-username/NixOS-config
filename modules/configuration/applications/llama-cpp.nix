# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.llama-cpp = {
      lib,
      config,
      pkgs,
      ...
    }: {
      preservation.preserveAt = lib.mkIf config.custom.preservation.enable {
        "/persist" = {
          users.${config.custom.user.name} = {
            directories = [
              ".cache/llama.cpp"
              ".cache/huggingface"
            ];
          };
        };
      };

      home-manager.users.${config.custom.user.name} = _: {
        home.packages = with pkgs; [
          llama-cpp-vulkan
        ];
      };
    };
  };
}
