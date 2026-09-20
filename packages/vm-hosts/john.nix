# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{self, ...}: {
  perSystem = _: {
    apps.john.program = "${self.nixosConfigurations.john.config.system.build.vm}/bin/run-john-vm";
  };
}
