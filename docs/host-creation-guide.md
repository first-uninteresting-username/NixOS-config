# Host creation guide

> [!ATTENTION]
> The hardware you will be running this config on needs to be relatively modern system with UEFI support.
> You are on your own with unsupported hardware.

## Steps

### (Outsiders only) Fork this repo

Fork this repo. You can do that with github webui or `gh` CLI tool:

```bash
gh repo fork first-uninteresting-username/NixOS-config
```

It might be a good idea to let me know that you are a user of this config, so I can provide assistance to you and ship less breaking changes.

### Choose a base host and a host name

Select a host you want to base your host on and a name for your host.

Naming hosts and a few host names I came up with are available in [host-names.md](host-names.md) doc.

You should base your host on the `template` host, unless your host is very similiar to another, existising host.

### Copy base host directory and adjust hostname

Hostname should be in top level `let ...  in` block as `Hostname` in `default.nix` file in the root of your host (from this point that location is assumed).

Also, in the same file, change the system, if your CPU arch is different than x86_64.

### Adjust hardware configuration

Write your [disko](https://github.com/nix-community/disko) config to `disko.nix`.

Create [nix facter](https://github.com/nix-community/nixos-facter) config (run in your host root or move the resulting facter.json there after run):

```bash
sudo nix run --option experimental-features "nix-command flakes" nixpkgs#nixos-facter -- -o facter.json
```

Import [nixos hardware](https://github.com/nixos/nixos-hardware) modules in `hardware.nix` in imports sections.
You can address those modules by `inputs.nixos-hardware.nixosModules.MODULE_NAME`.

Update `systemStateVersion` to NEXT RELEASE of NixOS. System state version should be tied to the time you installed your system.
When using unstable nixpkgs (like this config), you should use the next version, because your system identifies as such.

Get through `hardware.nix` and change things you want to change. template config has comments explaining what each option does.

## Add configuration modules

[Explanation of modules](modules.md)

In `default.nix` adjust the list of modules. In that file, you are supposed to put only configuration modules, ones that don't provide options.

In `modules.nix` import nixos modules you need and set their options.

## Write non modular configuration

Write any arbitrary nix options to `configuration.nix`. This might be helpful in case you don't want to create a module for some small thing.

## Create secrets (Needs a decryption key for secrets.yaml)

2 pairs SSH ed25519 keys:

for keypair

```bash
ssh-keygen -t ed25519 -C "HOST NAME"
```

and add to `secrets/secrets.yaml` in the root of this config in the same way as other ssh keys are added.

Age key:

```bash
sudo age-keygen -pq -o /var/lib/sops-nix/keys.txt
```

put the public key in `.sops.yaml`, add that whole file to `secrets/secrets.yaml` as a secret.

Password:

```bash
mkpasswd -m yescrypt
```

You know where to add it.

# You are done!
