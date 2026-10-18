# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib}: rec {
  requests = fn: builtins.attrNames (builtins.functionArgs fn);

  # Merge after the shallow type check to validate nested option types and defaults.
  validate = commonArgs: label: name: value:
    if builtins.hasAttr name commonArgs && !(commonArgs.${name}.type.check value)
    then throw "modules: ${label}: argument '${name}' must be ${commonArgs.${name}.type.description}"
    else if builtins.hasAttr name commonArgs
    then
      (lib.mergeDefinitions [name] commonArgs.${name}.type [
        {
          file = label;
          inherit value;
        }
      ]).mergedValue
    else value;

  # Omit optional parameters so Nix itself evaluates their lexical defaults.
  bind = {
    fn,
    values ? {},
    context ? {},
    fallback ? {},
    commonArgs ? {},
    label,
  }: let
    parameters = builtins.functionArgs fn;
    resolve = name: _:
      if builtins.hasAttr name values
      then validate commonArgs label name values.${name}
      else if builtins.hasAttr name context
      then validate commonArgs label name context.${name}
      else if builtins.hasAttr name fallback
      then validate commonArgs label name fallback.${name}
      else if (commonArgs.${name} or {}) ? default
      then validate commonArgs label name commonArgs.${name}.default
      else throw "modules: ${label}: missing required argument '${name}'";
    supplied = lib.mapAttrs resolve (lib.filterAttrs (
        name: optional:
          !optional || builtins.hasAttr name values || builtins.hasAttr name context
      )
      parameters);
  in {
    value = fn supplied;
    # Force supplied values separately so ignored parameters still report invalid types.
    required =
      builtins.foldl' (acc: value: builtins.seq value acc) true
      (builtins.attrValues supplied);
  };
}
