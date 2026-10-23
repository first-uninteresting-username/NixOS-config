# Package updates

Packages that pin an upstream release update the way Nixpkgs packages do. Each one
declares `passthru.updateScript` with `pkgs.nix-update-script`, and one runner executes
those scripts locally and in CI. Packages taken from flake inputs, such as `hack` and
`GNOME-hackastats`, update with `flake.lock` instead.

## Update packages

Run every update script from anywhere in the repository:

```bash
nix run .#update-packages
```

Pass export names to update only some packages:

```bash
nix run .#update-packages -- orchard-cli programs-desktop-flow-desktop
```

The runner edits the package sources in place; review, build, and commit the result
yourself. Set `GITHUB_TOKEN` to avoid GitHub API rate limits.

Each package updates separately. When one fails, the runner restores that package's files,
continues with the others, and exits with an error that names the failed packages. Earlier
successful updates and your other uncommitted changes remain.

Build each updated package and its checks before committing:

```bash
nix build .#orchard-cli .#checks.x86_64-linux.orchard-cli
```

## Scheduled updates

The **Update Packages** workflow runs the same command on Mondays and Thursdays. It opens
or updates the `chore(update)/package-updates` pull request with every successful update,
then fails the run if any package failed. A manual run accepts a JSON array of export
names; an empty array updates every package.

Package update pull requests always need a manual merge. Automatic merging accepts only
`flake.lock` changes; see the [checks guide](checks.md#automatic-dependency-merging).

## Add an updatable package

Keep `version` and every hash as literal strings in the module's Nix file. nix-update
rewrites them in place, so do not move pins into JSON or other generated files.

```nix
packages = {pkgs, ...}: let
  version = "1.2.3";
in {
  default = pkgs.rustPlatform.buildRustPackage {
    pname = "example";
    inherit version;
    src = pkgs.fetchFromGitHub {
      owner = "example";
      repo = "example";
      tag = "v${version}";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    passthru.updateScript = pkgs.nix-update-script {extraArgs = ["--flake"];};
  };
};
```

- Always pass `--flake`. Without it, nix-update looks for `default.nix` at the repository root.
- Omit `attrPath`. The runner supplies the export name through `UPDATE_NIX_ATTR_PATH`.
- nix-update also refreshes dependency hashes such as `cargoHash`, `vendorHash`, and
  `npmDepsHash`.
- When packages share a source, declare the script on one of them. The `ai-usagebar`
  GNOME extension updates with its CLI.
- Validate upstream changes that an update can break during the build or in a module check.
  For example, the `ai-usagebar` extension build fails when upstream drops support for the
  configured GNOME Shell version.

### Prebuilt binaries

For release assets built per architecture, keep one `fetchurl` per system in
`passthru.sources` and let nix-update refresh each one as a subpackage:

```nix
packages = {pkgs, ...}: let
  version = "1.2.3";
  sources = pkgs.lib.mapAttrs (_: source:
    pkgs.fetchurl {
      url = "https://github.com/example/example/releases/download/v${version}/example_${source.arch}.tar.gz";
      inherit (source) hash;
    }) {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };
in {
  default = pkgs.stdenvNoCC.mkDerivation {
    pname = "example";
    inherit version;
    src = sources.${pkgs.stdenv.hostPlatform.system};
    passthru = {
      inherit sources;
      updateScript = pkgs.nix-update-script {
        extraArgs = [
          "--flake"
          "--use-github-releases"
          "--override-filename"
          "modules/example/default.nix"
          "--subpackage"
          "sources.x86_64-linux"
          "--subpackage"
          "sources.aarch64-linux"
        ];
      };
    };
  };
};
```

`--override-filename` names the module file because each subpackage is a `fetchurl`
derivation whose source position lies in Nixpkgs. `--use-github-releases` reads the GitHub
release list and skips releases marked as pre-releases. `orchard-cli` and
`programs-desktop-flow-desktop` follow this pattern.

## Selection

`github-actions/package-updates.nix` defines the runner. It includes every exported package
that has `passthru.updateScript` and is declared in this repository, which nix-update requires
to edit its source.
