# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Flat xfwm4 theme with rounded top corners and round title buttons, drawn from base16 colors.
{
  lib,
  pkgs,
  colors,
  name ? "Stylix",
}: let
  height = 34;
  radius = 10;
  buttonWidth = 26;
  dot = 14;
  states = {
    active = {
      title = colors.base01;
      border = colors.base02;
    };
    inactive = {
      title = colors.base00;
      border = colors.base01;
    };
  };
  # The traffic-light colors show on focused windows; unfocused ones turn grey.
  buttons = {
    close = colors.base08;
    maximize = colors.base0B;
    maximize-toggled = colors.base0B;
    hide = colors.base0A;
    menu = colors.base0D;
    shade = colors.base0C;
    stick = colors.base0E;
  };
  glyphs = let
    c = buttonWidth / 2;
    m = height / 2;
    l = toString (c - 3);
    r = toString (c + 3);
    t = toString (m - 3);
    b = toString (m + 3);
    cx = toString c;
    cy = toString m;
  in {
    close = "line ${l},${t} ${r},${b} line ${l},${b} ${r},${t}";
    maximize = "line ${l},${cy} ${r},${cy} line ${cx},${t} ${cx},${b}";
    maximize-toggled = "line ${l},${cy} ${r},${cy}";
    hide = "line ${l},${cy} ${r},${cy}";
    menu = "point ${cx},${cy}";
    shade = "line ${l},${t} ${r},${t}";
    stick = "point ${cx},${cy}";
  };
  magick = lib.getExe pkgs.imagemagick;
  c0 = toString (buttonWidth / 2);
  m0 = toString (height / 2);
  edge = toString (buttonWidth / 2 + dot / 2);
  button = state: btn: variant: let
    fill =
      if state == "inactive" && variant != "prelight"
      then colors.base03
      else buttons.${btn};
    glyph = lib.optionalString (variant == "prelight" || variant == "pressed") ''
      -stroke '${colors.base00}' -strokewidth 1.6 -draw '${glyphs.${btn}}' \
    '';
    file = "${btn}-${state}${lib.optionalString (variant != "") "-${variant}"}.png";
  in ''
    ${magick} -size ${toString buttonWidth}x${toString height} 'xc:${states.${state}.title}' \
      -fill '${fill}' -draw 'circle ${c0},${m0} ${edge},${m0}' \
      ${glyph} $out/xfwm4/${file}
  '';
  frame = state: let
    s = states.${state};
    w = toString radius;
    h = toString height;
    r = toString radius;
  in ''
    ${magick} -size 1x${h} 'xc:${s.title}' $out/xfwm4/title-1-${state}.png
    for i in 2 3 4 5; do cp $out/xfwm4/title-1-${state}.png $out/xfwm4/title-$i-${state}.png; done
    ${magick} -size ${w}x${h} xc:none -fill '${s.title}' \
      -draw 'roundrectangle 0,0 ${toString (radius * 3)},${toString (height + radius)} ${r},${r}' \
      $out/xfwm4/top-left-${state}.png
    ${magick} $out/xfwm4/top-left-${state}.png -flop $out/xfwm4/top-right-${state}.png
    for part in left right bottom bottom-left bottom-right; do
      ${magick} -size 1x1 'xc:${s.border}' $out/xfwm4/$part-${state}.png
    done
  '';
in
  pkgs.runCommand "xfwm4-theme-${name}" {} ''
    mkdir -p $out/xfwm4
    cat > $out/xfwm4/themerc <<EOF
    button_offset=8
    button_spacing=0
    full_width_title=true
    title_alignment=center
    title_shadow_active=false
    title_shadow_inactive=false
    title_vertical_offset_active=0
    title_vertical_offset_inactive=0
    active_text_color=${colors.base05}
    inactive_text_color=${colors.base04}
    shadow_delta_height=2
    shadow_delta_width=0
    shadow_delta_x=0
    shadow_delta_y=-4
    shadow_opacity=40
    EOF
    ${lib.concatMapStrings frame ["active" "inactive"]}
    ${lib.concatStrings (lib.mapCartesianProduct ({
      state,
      btn,
      variant,
    }:
      button state btn variant) {
      state = ["active" "inactive"];
      btn = lib.attrNames buttons;
      variant = ["" "prelight" "pressed"];
    })}
  ''
