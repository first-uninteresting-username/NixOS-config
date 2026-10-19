# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{lib, ...}: {
  secretsEnable = {
    type = lib.types.bool;
    description = "Decrypt and use sops-managed credentials. Select the secrets module when enabled.";
    default = false;
  };
}
