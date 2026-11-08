# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{mkModule, ...}: let
  providerDir = ./_providers;
in
  mkModule {
    name = "opencode-providers";
    ids = ["agents"];
    module = {opencodeProviderSecretDir ? "/run/secrets/opencode-providers"}: let
      # Each _providers/<id>.json holds an OpenCode `providers.<id>` entry. The extra
      # `apiKeySecret` field names the sops secret that holds the provider's API key.
      providers = builtins.listToAttrs (map (file: {
          name = builtins.replaceStrings [".json"] [""] file;
          value = builtins.fromJSON (builtins.readFile (providerDir + "/${file}"));
        }) (builtins.filter (f: builtins.match ".*\\.json" f != null)
          (builtins.attrNames (builtins.readDir providerDir))));
      secretPath = provider: "${opencodeProviderSecretDir}/${provider.apiKeySecret}";
      withSecret = provider: provider ? apiKeySecret;
    in {
      nixos = {
        lib,
        secretsEnable,
        userName,
        ...
      }: {
        config = lib.optionalAttrs secretsEnable {
          sops.secrets = lib.mapAttrs' (_: provider:
            lib.nameValuePair provider.apiKeySecret {
              path = secretPath provider;
              owner = userName;
            })
          (lib.filterAttrs (_: withSecret) providers);
        };
      };
      home = {
        lib,
        secretsEnable,
        ...
      }: {
        # OpenCode substitutes the {file:} reference at startup, so keys stay out of the store.
        programs.opencode.settings.providers = lib.mapAttrs (_: provider:
          lib.recursiveUpdate (removeAttrs provider ["apiKeySecret"])
          (lib.optionalAttrs (secretsEnable && withSecret provider) {
            settings.apiKey = "{file:${secretPath provider}}";
          }))
        providers;
      };
    };
    packages = {pkgs, ...}: {
      # Refreshes a provider file's model list from its OpenAI-compatible /models endpoint.
      # Existing per-model settings are kept; models the endpoint no longer lists are removed.
      sync-models = pkgs.writeShellApplication {
        name = "opencode-provider-sync-models";
        runtimeInputs = [pkgs.curl pkgs.jq];
        text = ''
          if [ $# -ne 1 ]; then
            echo "usage: opencode-provider-sync-models <provider.json>" >&2
            exit 2
          fi
          file=$1
          baseUrl=$(jq -er '.settings.baseURL' "$file")
          secret=$(jq -r '.apiKeySecret // empty' "$file")
          auth=()
          if [ -n "$secret" ]; then
            keyFile=''${OPENCODE_PROVIDER_SECRET_DIR:-/run/secrets/opencode-providers}/$secret
            auth=(-H "Authorization: Bearer $(cat "$keyFile")")
          fi
          ids=$(curl -fsS "''${auth[@]}" "''${baseUrl%/}/models" | jq '[.data[].id]')
          tmp=$(mktemp)
          jq --argjson ids "$ids" '
            . as $p | .models = ([$ids[] | {key: ., value: ($p.models[.] // {})}] | sort_by(.key) | from_entries)
          ' "$file" > "$tmp"
          mv "$tmp" "$file"
          jq -r '"\(.models | length) models in \(input_filename)"' "$file"
        '';
      };
    };
    docs = ''
      The `agents` host ID enables this module. It adds an OpenCode provider for every
      `_providers/<id>.json` file in the module directory, using the file name as the
      provider ID. Each file is an OpenCode `providers.<id>` entry, with `name`, `package`,
      `settings.baseURL`, and a declared `models` list.

      The optional `apiKeySecret` field names a sops secret. With secrets enabled, sops-nix
      decrypts it to `opencodeProviderSecretDir/<secret>`, and OpenCode reads it through a
      `{file:}` reference in `settings.apiKey`. The key stays out of the Nix store.

      To add a provider, create its JSON file, add its key to sops, and rebuild. To refresh a
      model list from an OpenAI-compatible `/models` endpoint, run:

      ```bash
      nix run .#opencode-providers-sync-models -- modules/opencode-providers/_providers/<id>.json
      ```
    '';
    imperativeSteps = ''
      With secrets enabled, store each provider's API key in sops under the name given by its
      `apiKeySecret` field:

      ```bash
      sops-easy secrets/secrets.yaml
      ```
    '';
  }
