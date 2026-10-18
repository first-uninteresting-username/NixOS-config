# Module argument reference

> Auto-generated from the common argument declarations in `arguments/`.
> Run `nix run .#module-docs-update` to regenerate. Do not edit manually.

Hosts pass these settings through `args`. Selected modules request only the
arguments needed by their applicable system and home sections.

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



## theme



Settings for theme\.



*Type:*
submodule



*Default:*

```nix
{
  base16Scheme = "grayscale-dark";
  enable = false;
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


