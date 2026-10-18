# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib, ...}: {
  theme = {
    description = "Settings for theme.";
    default = {};
    type = lib.types.submodule (_: {
      options = {
        enable = lib.mkEnableOption "opinionated styling with stylix";
        image = {
          enable = lib.mkEnableOption "wallpaper generation";
          width = lib.mkOption {
            type = lib.types.str;
            default = "1920";
            example = "3840";
            description = "Width of main monitor";
          };
          height = lib.mkOption {
            type = lib.types.str;
            default = "1080";
            example = "2160";
            description = "Height of main monitor";
          };
          path = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            example = lib.literalExpression "./my-wallpaper.svg";
            description = "SVG file to use as wallpaper. When null the default theme-coloured SVG is generated.";
          };
        };

        base16Scheme = lib.mkOption {
          type = lib.types.str;
          default = "grayscale-dark";
          example = "gruvbox-dark";
          description = "Name of the base16 scheme in base16-schemes package in nixpkgs";
        };
      };
    });
  };
}
