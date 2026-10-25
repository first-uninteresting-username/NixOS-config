# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  config,
  lib,
  pkgs,
  inputs,
  theme,
}: let
  cfg = theme;
  inherit (config.lib.stylix) colors;

  defaultSvgContent = ''
    <svg height="2160" viewBox="0 0 3840 2160" width="3840"
         xmlns="http://www.w3.org/2000/svg">
      <path d="M0 0h3840v2160H0z" fill="#${colors.base00}"/>
      <g fill-rule="evenodd" transform="translate(416.4 267.6) scale(6.578)">
        <path d="m194.168 125.017 32.017 55.46-14.714.138-8.548-14.9-8.608 14.82-7.31-.003-3.745-6.468 12.265-21.09-8.707-15.15z" fill="#${colors.base0C}"/>
        <path d="m205.725 102.173-32.022 55.458-7.476-12.674 8.63-14.852-17.14-.046-3.653-6.332 3.73-6.478 24.396.078 8.769-15.117z" fill="#${colors.base0E}"/>
        <path d="m208.18 146.506 64.04.003-7.238 12.812-17.178-.048 8.53 14.866-3.657 6.33-7.475.008-12.131-21.166-17.474-.036z" fill="#${colors.base0B}"/>
        <path d="m245.453 122.202-32.017-55.46 14.714-.138 8.548 14.9 8.608-14.82 7.31.002 3.745 6.47-12.265 21.088 8.707 15.151z" fill="#${colors.base09}"/>
        <path d="m231.352 100.578-64.038-.003 7.237-12.812 17.178.047-8.53-14.865 3.657-6.33 7.475-.008 12.131 21.166 17.474.035z" fill="#${colors.base08}"/>
        <path d="M233.858 145.039 265.88 89.58l7.476 12.673-8.63 14.853 17.14.045 3.652 6.333-3.73 6.477-24.396-.077L248.624 145z" fill="#${colors.base0A}"/>
      </g>
    </svg>
  '';
  svgSource =
    if cfg.image.path != null
    then cfg.image.path
    else pkgs.writeText "wallpaper.svg" defaultSvgContent;

  generatedImage = pkgs.runCommand "wallpaper.png" {} ''
    ${lib.getExe pkgs.imagemagick} \
      -density 96 \
      ${svgSource} \
      -resize ${cfg.image.width}x${cfg.image.height}! \
      -flatten \
      $out
  '';
in {
  base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/${cfg.base16Scheme}.yaml";
  polarity = "dark";
  image = lib.mkIf cfg.image.enable generatedImage;

  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  icons = {
    enable = true;
    package = pkgs.morewaita-icon-theme;
    dark = "MoreWaita";
    light = "MoreWaita";
  };

  fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };
    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };
}
