# Modules

My module system is utterly stupid, borderline useless and not well thought.

I'm working on fixing it, but for now it works. Barely.

I split my modules on 2 groups:

(This grouping is completely arbitrary and based on the function of modules)

## Configuration

Those modules require reusable functions from nixos modules to work properly.

List:

```nix
nixosModules.browser
nixosModules.audio
nixosModules.gaming-distrobox
nixosModules.gaming
nixosModules.programs-desktop
nixosModules.sudo
nixosModules.input
nixosModules.printing
nixosModules.tty
nixosModules.wayland
nixosModules.IDE
nixosModules.agents
nixosModules.git
nixosModules.secretless-git
nixosModules.iso-graphical
nixosModules.iso-terminal
nixosModules.smart
nixosModules.ssh
nixosModules.secretless-ssh
nixosModules.ssh-debug
nixosModules.ssh-server
nixosModules.sunshine
nixosModules.moonlight
nixosModules.update
nixosModules.virtualization-desktop
nixosModules.virtualization-server
nixosModules.windows-vm
nixosModules.locale
nixosModules.networking-desktop
nixosModules.secretless-networking-desktop
nixosModules.networking-server
nixosModules.networking-minimal
nixosModules.nix
nixosModules.power
nixosModules.secrets
nixosModules.home-manager
nixosModules.xdg
```

There're no docs for those modules, because no current users need them.

<!-- Hardcoding, because by the time I will need to change it, I hope to have a new module system (modules v3) -->

## Nixos

Those are self contained modules, but they're useless without setting `custom.WHATEVER-MODULE-PROVIDES`.

They're needed for some of configuration modules.

[Docs](/docs/module-reference.md)
