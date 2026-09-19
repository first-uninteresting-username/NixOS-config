# Install Guide (feat. Nixos Anywhere)

## Prequsites

- Machine with Nix (with flakes) installed (from this point called `source`). It's reccomended that this isn't a potato
- Target machine (`target` from this point)
- Host config prepared (see [host creation guide]](host-creation-guide.md) for more informations)
- Age `keys.txt` file linked with the host (if you followed that [host creation guide]](host-creation-guide.md) you should have it somewhere)
- Clean workspace

## Steps

### Make sure target is accessible from source via ssh

You must have access to the root account.
ISOs that come with this config can be accessed via SSH open with `nixos` password.

### Seed the age key

Put your `keys.txt` file in `./tmp/var/lib/sops-nix/keys.txt` in the workspace. That tmp part can be whatever, just be consistant with it.
Add `/persist` to the path if your config uses the preservation module (so the path is `./tmp/persist/var/lib/sops-nix/keys.txt`).

Give it correct permissions:

```bash
# Omit persist if not using preservation
sudo chown root:root ./tmp/persist/var/lib/sops-nix/keys.txt
sudo chmod 600 ./tmp/persist/var/lib/sops-nix/keys.txt
sudo chown root:root ./tmp/persist/var/lib/sops-nix
sudo chmod 700 ./tmp/persist/var/lib/sops-nix
```

### Install

`HOST-NAME` is the name of your host
`IP` is the ip or hostname you are accessing target with

Run (on the source):

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake "github:first-uninteresting-username/NixOS-config#HOST-NAME" \
  --extra-files ./tmp \
  --target-host "root@IP"
```

```nushell
^nix run github:nix-community/nixos-anywhere -- --flake 'github:first-uninteresting-username/NixOS-config#HOST-NAME' --extra-files ./tmp --target-host 'root@IP'
```

## Post installation

Log in to password manager, matrix etc

It might be a good idea to regenerate facter hardware config after the first boot.
