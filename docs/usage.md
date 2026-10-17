# Usage docs

## Home directories and terminals

XDG user folders live directly under your home directory: `~/Downloads`, `~/Documents`,
`~/Pictures`, `~/Templates`, `~/Videos`, `~/Projects`, and `~/Games`.
When preservation is enabled, each folder is persisted separately. `~/persist` remains
persisted for other files. Terminal shells keep the directory supplied by their launcher,
so **Open in Terminal** in Files opens the selected folder.

### Migrate existing folders

Before rebooting into this configuration, move existing files from the old persistent
layout to the new backing directories under `/persist/home/<user>/`. For example,
`/persist/home/<user>/persist/Documents` moves to `/persist/home/<user>/Documents`.
Repeat for each folder listed above. If a destination already contains files, merge its
contents carefully instead of replacing the directory. Also preserve files that applications
have already placed in the corresponding folders directly under your home directory.

Do this while the affected applications are closed, and reboot after the configuration
is installed so preservation mounts the new folders. The configuration does not move
existing files automatically. Update bookmarks, shortcuts, and project paths that still
refer to `~/persist/Projects` or the other old locations.

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

### CloudRedirect release updates

The `nix-crab` input pins CloudRedirect's upstream hook to a versioned release URL.
This keeps dependency updates and CI from fetching different files through the moving `latest` URL.

To update the hook, change the release version in
`inputs.nix-crab.inputs.cloudredirect.url` in `flake.nix`, then run:

```bash
nix flake update nix-crab/cloudredirect
nix flake check --no-build
```

The regular flake update keeps this release pinned until you change its URL.

### Zed with ChatGPT Plus

The `IDE` module enables Zed's Agent panel and its status bar button.
Zed's ChatGPT Subscription provider supports ChatGPT Plus and Pro accounts.

1. Rebuild your system with the updated configuration and restart Zed.
2. Open **Settings > AI > LLM Providers** and select **ChatGPT Subscription**.
3. Click **Sign In** and complete the browser login with your ChatGPT Plus account.
4. Open the Agent panel with its status bar button and select a model from
   **ChatGPT Subscription** in the model picker.

No separate OpenAI API key is required. OpenAI API billing is separate from your
ChatGPT subscription. Zed stores the login credentials in your system keychain.

See Zed's [existing subscription guide](https://zed.dev/docs/ai/use-an-existing-subscription#chatgpt).

## External

External usage is highly dependant on your nixos configuration framework.

Currently, I'm the only user of this flake.
If you are interested in using anything from this flake and don't know how to do it, please create an issue, I will try to help you.
If you use this flake, please create a section for your framework.

Generally, you almost always need `custom.user = "name-of-your-user"` set. You also need to have home manager enabled.
