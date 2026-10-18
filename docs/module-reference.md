# Module argument reference

> Auto-generated from the common argument declarations in `arguments/`.
> Run `nix run .#module-docs-update` to regenerate. Do not edit manually.

Hosts pass these settings through `args`. Selected modules request only the
arguments needed by their applicable system and home sections.

## desktop

Settings for desktop\.



*Type:*
submodule



*Default:*

```nix
{
  enable = false;
  name = null;
  programs = {
    archiveTool = null;
    calculator = null;
    calendar = null;
    characterSelector = null;
    chess = null;
    clock = null;
    diskUsageViewer = null;
    documentViewer = null;
    fileManager = null;
    imageViewer = null;
    isoWriter = null;
    matrixClient = null;
    musicPlayer = null;
    paintingApp = null;
    screenshotUtility = null;
    systemMonitor = null;
    terminalEmulator = null;
    textEditor = null;
    whiteboard = null;
  };
}
```



## desktop\.enable



Whether to enable DE configuration\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## desktop\.name



Name of the desktop envinronement to be enabled and configured



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.archiveTool



Which desktop-environment-specific utility to use for “archiveTool”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.calculator



Which desktop-environment-specific utility to use for “calculator”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.calendar



Which desktop-environment-specific utility to use for “calendar”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.characterSelector



Which desktop-environment-specific utility to use for “characterSelector”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.chess



Which desktop-environment-specific utility to use for “chess”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.clock



Which desktop-environment-specific utility to use for “clock”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.diskUsageViewer



Which desktop-environment-specific utility to use for “diskUsageViewer”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.documentViewer



Which desktop-environment-specific utility to use for “documentViewer”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.fileManager



Which desktop-environment-specific utility to use for “fileManager”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.imageViewer



Which desktop-environment-specific utility to use for “imageViewer”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.isoWriter



Which desktop-environment-specific utility to use for “isoWriter”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.matrixClient



Which desktop-environment-specific utility to use for “matrixClient”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.musicPlayer



Which desktop-environment-specific utility to use for “musicPlayer”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.paintingApp



Which desktop-environment-specific utility to use for “paintingApp”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.screenshotUtility



Which desktop-environment-specific utility to use for “screenshotUtility”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.systemMonitor



Which desktop-environment-specific utility to use for “systemMonitor”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.terminalEmulator



Which desktop-environment-specific utility to use for “terminalEmulator”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.textEditor



Which desktop-environment-specific utility to use for “textEditor”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## desktop\.programs\.whiteboard



Which desktop-environment-specific utility to use for “whiteboard”\.
Set to “gnome” to pull in that DE’s tool, or null to disable/skip\.



*Type:*
null or one of “gnome”, “blank”



*Default:*

```nix
null
```



*Example:*

```nix
"gnome"
```



## homeStateVersion



Home Manager compatibility version\.



*Type:*
string



*Default:*

```nix
"26.11"
```



## preservationEnable



Persist state under /persist\.



*Type:*
boolean



*Default:*

```nix
false
```



## shell



Settings for shell\.



*Type:*
submodule



*Default:*

```nix
{
  enable = false;
  name = null;
}
```



## shell\.enable



Whether to enable shell config\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## shell\.name



Name of the shell to be enabled and configured



*Type:*
null or one of “nushell”, “zsh”



*Default:*

```nix
null
```



*Example:*

```nix
"nushell"
```



## theme



Settings for theme\.



*Type:*
submodule



*Default:*

```nix
{
  base16Scheme = "grayscale-dark";
  enable = false;
  icons = {
    name = null;
    package = null;
  };
  image = {
    enable = false;
    height = "1080";
    path = null;
    width = "1920";
  };
}
```



## theme\.enable



Whether to enable opinionated styling with stylix\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## theme\.base16Scheme



Name of the base16 scheme in base16-schemes package in nixpkgs



*Type:*
string



*Default:*

```nix
"grayscale-dark"
```



*Example:*

```nix
"gruvbox-dark"
```



## theme\.icons\.package



Name of the package used for icon theme



*Type:*
null or package



*Default:*

```nix
null
```



*Example:*

```nix
pkgs.morewaita-icon-theme
```



## theme\.icons\.name



Name of the icon theme, must match icon theme in package



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"MoreWaita"
```



## theme\.image\.enable



Whether to enable wallpaper generation\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```



## theme\.image\.height



Height of main monitor



*Type:*
string



*Default:*

```nix
"1080"
```



*Example:*

```nix
"2160"
```



## theme\.image\.path



SVG file to use as wallpaper\. When null the default theme-coloured SVG is generated\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
./my-wallpaper.svg
```



## theme\.image\.width



Width of main monitor



*Type:*
string



*Default:*

```nix
"1920"
```



*Example:*

```nix
"3840"
```



## userEnable



Create the NixOS user\.



*Type:*
boolean



*Default:*

```nix
false
```



## userHashedPassword



User password hash\.



*Type:*
null or string



*Default:*

```nix
null
```



## userHashedPasswordFile



Path to the user’s password hash file\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



## userName



Home Manager user name\.



*Type:*
string



*Default:*

```nix
"user"
```



## userPassword



Initial user password (public fixtures only)\.



*Type:*
null or string



*Default:*

```nix
null
```


