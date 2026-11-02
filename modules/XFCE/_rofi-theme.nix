# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# A centered, search-first launcher in the base16 palette.
{
  config,
  colors,
  uiFont,
}: let
  inherit (config.lib.formats.rasi) mkLiteral;
in {
  "*" = {
    bg = mkLiteral colors.base00;
    bg-alt = mkLiteral colors.base01;
    fg = mkLiteral colors.base05;
    fg-dim = mkLiteral colors.base04;
    accent = mkLiteral colors.base0D;
    font = "${uiFont} 12";
    background-color = mkLiteral "transparent";
    text-color = mkLiteral "@fg";
    margin = 0;
    padding = 0;
    spacing = 0;
  };
  window = {
    width = mkLiteral "640px";
    location = mkLiteral "center";
    anchor = mkLiteral "center";
    y-offset = mkLiteral "-120px";
    border = mkLiteral "1px";
    border-color = mkLiteral "@bg-alt";
    border-radius = mkLiteral "16px";
    background-color = mkLiteral "@bg";
  };
  mainbox = {
    padding = mkLiteral "12px";
    children = map mkLiteral ["inputbar" "listview"];
  };
  inputbar = {
    padding = mkLiteral "10px 14px";
    spacing = mkLiteral "10px";
    border-radius = mkLiteral "10px";
    background-color = mkLiteral "@bg-alt";
    children = map mkLiteral ["prompt" "entry"];
  };
  prompt.text-color = mkLiteral "@accent";
  entry = {
    placeholder = "Search";
    placeholder-color = mkLiteral "@fg-dim";
    cursor = mkLiteral "text";
  };
  listview = {
    lines = 7;
    fixed-height = false;
    scrollbar = false;
    margin = mkLiteral "10px 0 0 0";
    spacing = mkLiteral "2px";
  };
  element = {
    padding = mkLiteral "8px 12px";
    spacing = mkLiteral "12px";
    border-radius = mkLiteral "8px";
  };
  "element selected" = {
    background-color = mkLiteral "@accent";
    text-color = mkLiteral "@bg";
  };
  element-icon = {
    size = mkLiteral "24px";
    vertical-align = mkLiteral "0.5";
  };
  element-text = {
    text-color = mkLiteral "inherit";
    vertical-align = mkLiteral "0.5";
  };
}
