# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  lib,
  nixosConfigurations,
}: let
  expectations = import ./hosts.nix;
  evaluate = name: {
    host,
    option,
    expected,
  }: let
    actual = lib.getAttrFromPath option nixosConfigurations.${host}.config;
    path = lib.concatStringsSep "." option;
  in
    if actual == expected
    then true
    else
      throw (
        "Eval test ${name}: ${host}.${path}: "
        + "expected ${builtins.toJSON expected}, got ${builtins.toJSON actual}"
      );
in
  lib.mapAttrs evaluate expectations
