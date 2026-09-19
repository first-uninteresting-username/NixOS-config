# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  flake = {
    nixosModules.locale = _: {
      # Waiting for en_EU locale
      i18n.defaultLocale = "en_US.UTF-8";

      i18n.extraLocaleSettings = {
        LC_MESSAGES = "en_US.UTF-8";
        LC_TIME = "en_DK.UTF-8";
        LC_MONETARY = "pl_PL.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_DK.UTF-8";
        LC_ADDRESS = "pl_PL.UTF-8";
        LC_TELEPHONE = "pl_PL.UTF-8";
        LC_MEASUREMENT = "en_DK.UTF-8";
        LC_NAME = "pl_PL.UTF-8";
        LC_IDENTIFICATION = "pl_PL.UTF-8";
        LC_CTYPE = "en_US.UTF-8";
        LC_COLLATE = "en_US.UTF-8";
      };

      time.timeZone = "Europe/Warsaw";
    };
  };
}
