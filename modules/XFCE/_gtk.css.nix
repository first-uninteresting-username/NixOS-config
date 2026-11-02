# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Panel, dock and terminal styling layered over the Stylix GTK theme.
{colors}: ''
  .xfce4-panel button {
    border-radius: 8px;
    padding: 0 8px;
    margin: 3px 1px;
  }
  .xfce4-panel.panel-1 button:hover {
    background-color: ${colors.base02};
  }

  /* Workspace pager: small pills, the current one highlighted. */
  #pager-31 button {
    min-width: 24px;
    padding: 0 6px;
  }
  #pager-31 button:checked {
    background-color: ${colors.base0D};
    color: ${colors.base00};
  }

  /* The dock panel is transparent; the plugin draws a rounded tray inside it. */
  #docklike-plugin {
    background-color: alpha(${colors.base01}, 0.92);
    border: 1px solid ${colors.base02};
    border-radius: 16px;
    padding: 0 6px;
    margin: 0 0 6px 0;
  }
  .xfce4-panel.panel-2 button {
    margin: 4px 2px;
    padding: 4px;
    border-radius: 12px;
  }

  vte-terminal {
    padding: 10px 12px;
  }

  menu,
  .menu,
  .context-menu {
    border-radius: 10px;
    padding: 4px;
  }
  menu menuitem {
    border-radius: 6px;
    padding: 6px 10px;
  }
''
