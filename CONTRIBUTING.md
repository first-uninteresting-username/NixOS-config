# Contributing

This is a private repo. If you want to use elements to it, refer to [usage docs](usage.md). If you want to use just it, fork it.

I can provide assistance with your fork, but I reserve the right to not do that without reason.

I won't be stopping anyone from forking this repo.

## Dev setup

This project uses [devenv](https://devenv.sh/).

Run:

```bash
# One time usage
devenv shell
# If you plan to code in multiple sessions and you trust me, it's better to allow the devenv shell to run each time:
devenv allow
```

If for some reason you can't install nix locally, a devcontainer is available.

## Running tests

Before each commit (pre-commit won't allow you to commit otherwise), run:

```bash
alejandra .
```

Before submitting a PR, eval the flake with:

```bash
# Omiting "--no-build" will result in building VM checks
nix flake check --no-build
```

## Commit conventions

I use relaxed version of [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/).

As long as your commit uses the format of `category: what you did` it is fine.

## Style

Use alejandra (pre-commit won't let you commit without that).

Do not use nix antipatterns, such as `with lib;`.

Copy templates for modules, they're clear enough in my opinion.

Add checks for features you add.

## Getting help/reporting issues/asking questions

Use [github issues](https://github.com/first-uninteresting-username/NixOS-config)
