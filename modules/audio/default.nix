# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}:
mkModule {
  name = "audio";
  ids = ["audio"];
  module = _: {
    nixos = {
      pkgs,
      lib,
      ...
    }: let
      # The Solum Voice S Mic (USB 3738:00a4) captures through a hardware mute
      # feature unit that the device powers up engaged, so it hands PipeWire a
      # valid stream of digital zeros. The control is volatile and resets on
      # every replug, so clear it whenever the card shows up.
      micCaptureUnmute = pkgs.writeShellScript "mic-capture-unmute" ''
        set -euo pipefail
        export PATH=${lib.makeBinPath [pkgs.alsa-utils pkgs.coreutils pkgs.gawk]}

        card=""
        for path in /sys/class/sound/card[0-9]*; do
          if [ ! -d "$path" ]; then
            continue
          fi
          dir="$(readlink -f "$path/device")"
          while [ -n "$dir" ] && [ "$dir" != "/" ]; do
            if [ -r "$dir/idVendor" ]; then
              if [ "$(cat "$dir/idVendor")" = "3738" ] &&
                 [ "$(cat "$dir/idProduct")" = "00a4" ]; then
                card="''${path##*card}"
              fi
              break
            fi
            dir="$(dirname "$dir")"
          done
          if [ -n "$card" ]; then
            break
          fi
        done

        if [ -z "$card" ]; then
          echo "Solum Voice S Mic (3738:00a4) is not present, nothing to unmute" >&2
          exit 0
        fi

        # The "Mic" simple control joins its playback and capture switches, so
        # amixer only ever clears the playback one. Address the capture switch
        # by name instead and set it through its own numid.
        numid="$(amixer -c "$card" contents |
          awk -F, "/name='Mic Capture Switch'/ {gsub(/numid=/, \"\", \$1); print \$1}")"

        if [ -z "$numid" ]; then
          echo "card $card has no 'Mic Capture Switch' control, leaving it alone" >&2
          exit 0
        fi

        # Force a hardware write even if the cached switch already reads as on.
        amixer -c "$card" cset "numid=$numid" 0
        amixer -c "$card" cset "numid=$numid" 1
      '';
    in {
      services.pulseaudio.enable = false;

      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };

      services.udev.extraRules = lib.mkAfter ''
        ACTION=="add", SUBSYSTEM=="sound", \
        ATTRS{idVendor}=="3738", ATTRS{idProduct}=="00a4", \
        TAG+="systemd", ENV{SYSTEMD_WANTS}+="mic-capture-unmute.service"
      '';

      systemd.services.mic-capture-unmute = {
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${micCaptureUnmute}";
        };
      };
    };
    home = {
      pkgs,
      lib,
      ...
    }: let
      solumDevice = "alsa_card.usb-Solum_Voice_S_Mic_Solum_Voice_S_Mic-00";

      # At login WirePlumber can activate the Solum's "on" profile without
      # creating its source and sink nodes. Cycling the profile creates them.
      micProfileReset = pkgs.writeShellScript "mic-profile-reset" ''
        set -euo pipefail
        export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.jq pkgs.pipewire pkgs.wireplumber]}

        id=""
        for _ in $(seq 30); do
          id="$(pw-dump | jq -r --arg name ${solumDevice} \
            '.[] | select(.info.props."device.name"? == $name) | .id' | head -n 1)"
          if [ -n "$id" ]; then
            break
          fi
          sleep 1
        done

        if [ -z "$id" ]; then
          echo "Solum Voice S Mic is not present, nothing to reset" >&2
          exit 0
        fi

        # Give WirePlumber a moment to create nodes on its own first.
        sleep 2
        nodes="$(pw-dump | jq --arg id "$id" \
          '[.[] | select(.info.props."device.id"? == ($id | tonumber))] | length')"
        if [ "$nodes" -gt 0 ]; then
          exit 0
        fi

        wpctl set-profile "$id" 0
        sleep 1
        wpctl set-profile "$id" 1
      '';
    in {
      systemd.user.services.mic-profile-reset = {
        Unit = {
          Description = "Create Solum Voice S Mic nodes missing after login";
          After = ["wireplumber.service"];
          PartOf = ["wireplumber.service"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${micProfileReset}";
        };
        Install.WantedBy = ["wireplumber.service"];
      };

      xdg.configFile."wireplumber/wireplumber.conf.d/50-solum-mic.conf".text = ''
        # The Solum Voice S Mic (USB 3738:00a4) is a UAC 1.0 device that ships
        # no UAC profile descriptors. PipeWire's ACP (alsa card profile)
        # manager selects the duplex "analog-stereo" profile but only
        # instantiates the playback side, so the capture stream is never
        # created and no source node appears. The capture endpoint is present
        # on the hardware (interface 2, EP 2 IN, mono 16-bit 44100/48000), so
        # fall back to PipeWire's legacy profile enumeration for this card,
        # which instantiates both directions.
        monitor.alsa.rules = [
          {
            matches = [
              {
                device.name = "~alsa_card.usb-Solum_Voice_S_Mic_Solum_Voice_S_Mic-00"
              }
            ]
            actions = {
              update-props = {
                api.alsa.use-acp = false
              }
            }
          }
        ]
      '';
    };
  };
}
