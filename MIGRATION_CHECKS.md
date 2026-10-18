# Remaining migration work

## Implementation gaps

- [x] Support `lib.mkIf` in shared assertions and add regression coverage.
  Shared assertions resolve through the module evaluator before their messages receive
  host/module context. Fixtures cover lazy disabled assertions, enabled failures, and
  nested `lib.mkIf`/`lib.mkMerge` on both host roles, including contextual diagnostics.
- [x] Build the production standalone Home Manager activation packages in their check.
  The check depends on both activation outputs and verifies their executable entry points.
  Both production GNOME/Nushell and independent Zsh activation packages build successfully.

## Argument-default contract

- [x] Resolve whether common-argument types must also validate function-parameter defaults.
  Retain ordinary Nix lexical defaults: their values are not introspectable, so common
  types validate supplied values and common defaults only. The constructor README now
  explicitly documents this boundary and how to request a validated common default.
  A regression fixture preserves defaults referring to lexical bindings and other parameters.

## Outstanding verification

- [ ] Complete final validation of the migration branch before cutover, including full
  flake evaluation on both supported systems and relevant package, documentation, host,
  behavioral, and ISO smoke-test builds. Distinguish existing results recorded in
  `MIGRATION.md` from checks still needing execution; evaluation does not run VM tests.
- [x] Verify generated local HTML interactively in a graphical browser, including
  navigation and bundled assets through `file://` URLs.
  The maintainer confirms that navigation and bundled assets work in a graphical browser.
  The browser tool itself rejects `file://` URLs, so this confirmation comes from the
  maintainer's manual check. The requested light/dark toggle also has rendered-HTML coverage.
- [ ] Complete maintainer review before cutover.
