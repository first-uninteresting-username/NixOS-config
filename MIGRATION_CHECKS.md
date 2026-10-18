# Remaining migration work

## Implementation gaps

- [ ] Support `lib.mkIf` in shared assertions and add regression coverage.
  `lib/modules/default.nix` maps over assertion results as a plain list, so
  `assertions = {lib}: lib.mkIf false [...]` fails with "expected a list but found a set".
- [ ] Build the production standalone Home Manager activation packages in their check.
  `modules/module-library/default.nix` currently forces the production and Zsh fixture
  activation-package `drvPath` values, then builds an empty marker. Activation-package
  build failures remain undetected by this check.

## Unresolved API limitation

- [ ] Resolve whether common-argument types must also validate function-parameter defaults.
  A common argument declared as `lib.types.port` accepts a module parameter default of
  `"wrong-type"`. The constructor README documents this limitation. Decide whether to
  retain that contract or change argument handling to validate these defaults.

## Outstanding verification

- [ ] Complete final validation of the migration branch before cutover, including full
  flake evaluation on both supported systems and relevant package, documentation, host,
  behavioral, and ISO smoke-test builds. Distinguish existing results recorded in
  `MIGRATION.md` from checks still needing execution; evaluation does not run VM tests.
- [ ] Verify generated local HTML interactively in a graphical browser, including
  navigation and bundled assets through `file://` URLs.
- [ ] Complete maintainer review before cutover.
