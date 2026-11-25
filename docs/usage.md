# Usage docs

## Internal

### Packages

All imported packages are available in self.

To use a package in a module, you need to:

- Add `self` to the top level inputs
- Add `pkgs` to the home manager or nixos module input (depending where you use it)
- Find the package name

After those steps are complete, you can address the package and use it with:

```nix
self.packages.${pkgs.stdenv.hostPlatform.system}.PACKAGE_NAME
```

### Modules

To use modules in other modules or configurations, you need to:

- Add `self` to the top level inputs
- Check if the module needs any other modules or options set to work
- Find the name of the module.

Using the module:

```nix
# Importing
imports = [
  self.nixosModules.MODULE_NAME
];
# Adding to module list in the host declaration
modules = [
  self.nixosModules.MODULE_NAME
];
```

### CloudRedirect

CloudRedirect is disabled in `modules/gaming/default.nix` because it is broken. Steam's client
is 64-bit now, and cloudredirect-moon only ships a 32-bit `cloud_redirect.so`, which the
client cannot load. Set `programs.nix-crab.cloudredirect.enable = true` again once
cloudredirect-moon publishes a 64-bit hook. The hook comes from nix-crab's
`cloudredirect-moon` input, so updating that input picks up a new build.

### Remote deployments

Hosts listed in `deploy/default.nix` are deployed with [deploy-rs](https://github.com/serokell/deploy-rs).
Hosts that select the `update` module get `rebuild-nisha` next to `rebuild`. It deploys `main` to nisha:

```bash
rebuild-nisha
```

Elsewhere, `nix run config#rebuild-nisha` does the same. To test a branch before merging, run
`nix run .#rebuild-nisha` from its checkout.

nisha builds its own closure, because the x86_64 hosts cannot build aarch64-linux. deploy-rs then asks for
your sudo password on nisha. If the new generation breaks SSH, deploy-rs rolls back to the previous one.
Extra arguments go to deploy-rs, for example `rebuild-nisha --dry-activate`.

### Editors

The `IDE` host ID installs the editor-independent tools: `micro` as `EDITOR`, `nil`, Alejandra,
the Android tools, and the `wakatime` module's Hackatime configuration. AI coding activity is
reported only for files under `~/Agents`. Add one editor ID next to it:

| Host ID | Editor | Use it when |
| --- | --- | --- |
| `ide-proper` | Gram | The host has a GPU. |
| `ide-lite` | Kate | The host renders on the CPU, for example over xrdp. |

```nix
ids = ["IDE" "ide-lite" ...];
```

Kate is configured to match Gram where Kate allows: the same language servers and formatters,
format on save, Hackatime heartbeats, and a similar layout.
Each module's own documentation lists the details.

## External

External usage is highly dependant on your nixos configuration framework.

Currently, I'm the only user of this flake.
If you are interested in using anything from this flake and don't know how to do it, please create an issue, I will try to help you.
If you use this flake, please create a section for your framework.

Generally, you almost always need `custom.user = "name-of-your-user"` set. You also need to have home manager enabled.
