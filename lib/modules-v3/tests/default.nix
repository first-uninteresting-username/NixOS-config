# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  system ? "x86_64-linux",
}: let
  lib = inputs.nixpkgs.lib;
  v3 = import ../. {inherit inputs;};
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  fails = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  commonArgs = {
    userName = {
      type = lib.types.str;
      description = "The fixture user.";
      default = "fixture";
    };
    shared = {
      type = lib.types.int;
      description = "A common default.";
      default = 17;
    };
  };
  base = v3.mkModule {
    name = "base";
    module = {
      userName,
      hostName ? "direct",
    }: {
      nixos = _: {
        networking.hostName = hostName;
        users.users.${userName}.isNormalUser = true;
        system.stateVersion = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      };
      home = _: {
        home.username = userName;
        home.homeDirectory = "/home/${userName}";
        home.stateVersion = "26.05";
      };
    };
  };
  example = v3.mkModule {
    name = "example";
    ids = ["desktop" "gaming"];
    module = {shared ? 23}: {
      nixos = {
        config,
        packages,
        systemOnly,
      }: {
        environment.etc."v3-test".text = "${config.networking.hostName}:${toString shared}:${systemOnly}";
        environment.systemPackages = [packages.default];
      };
      home = {
        config,
        packages,
        homeOnly ? "home-default",
      }: {
        home.file."v3-test".text = "${config.home.username}:${toString shared}:${homeOnly}";
        home.packages = [packages.default];
      };
    };
    packages = {pkgs, ...}: {
      default = pkgs.writeText "v3-owned-package" "owned";
      helper = pkgs.writeText "v3-helper" "helper";
    };
    checks = {
      pkgs,
      packages,
      mkHost,
      ...
    }: {
      default = pkgs.runCommand "v3-example-check" {} ''
        test "$(cat ${packages.default})" = owned
        test '${(mkHost {
          name = "check-fixture";
          role = "home";
          inherit system;
        }).config.home.username}' = fixture
        touch "$out"
      '';
    };
  };
  nixosOnly = v3.mkModule {
    name = "nixos-only";
    module = {unusedOuter}: {
      nixos = {missingSystemArgument}: {
        environment.etc."unused".text = unusedOuter + missingSystemArgument;
      };
    };
    assertions = _: throw "inactive assertions evaluated";
  };
  registry = v3.mkRegistry {
    inherit commonArgs;
    modules = [base example];
  };
  home = args:
    registry.mkHost ({
        name = "test-home";
        role = "home";
        inherit system;
      }
      // args);
  nixos = args:
    registry.mkHost ({
        name = "test-system";
        role = "nixos";
        inherit system;
      }
      // args);
  chosenIds = ["gaming" "desktop"];
  exports = registry.perSystem {inherit pkgs system;};
  withModules = modules:
    (v3.mkRegistry {
      inherit commonArgs;
      modules = [base] ++ modules;
    }).mkHost {
      name = "extra-home";
      role = "home";
      inherit system;
    };
  commonDefault = v3.mkModule {
    name = "common-default";
    module = {shared}: {home = _: {home.file."common".text = toString shared;};};
  };
  sharedAssertion = condition:
    v3.mkModule {
      name = "assertion";
      module = _: {home = _: {};};
      assertions = {config}: [
        {
          assertion = condition && config.home.username == "fixture";
          message = "shared fixture assertion";
        }
      ];
    };
  collision = field:
    v3.mkRegistry {
      modules = [
        (v3.mkModule {
          name = "one";
          ${field}.two = pkgs.hello;
        })
        (v3.mkModule {
          name = "one-two";
          ${field}.default = pkgs.hello;
        })
      ];
    };
  discovered = v3.discover {
    modulesDir = ./discovery/modules;
    hostsDir = ./discovery/hosts;
    argumentsDir = ./discovery/arguments;
  };
  onlyHome = v3.mkModule {
    name = "only-home";
    module = _: {home = {config}: {home.file."only-home".text = config.home.username;};};
  };
  sectionDefaults = v3.mkModule {
    name = "section-defaults";
    module = _: {home = {shared ? 29}: {home.file."section-defaults".text = toString shared;};};
  };
  noImplicitArgs = v3.mkModule {
    name = "explicit-args";
    module = {userName, ...} @ args: {
      home = {lib, ...} @ sectionArgs: {
        assertions = [
          {
            assertion = builtins.attrNames args == ["userName"];
            message = "enclosing argument leak";
          }
          {
            assertion = builtins.attrNames sectionArgs == ["lib"];
            message = "section argument leak";
          }
        ];
        home.file."explicit".text = lib.toUpper userName;
      };
    };
  };
  tests = {
    emptyIdsMatch = (home {}).config.home.username == "fixture";
    subsetDoesNotMatch = !((home {ids = ["gaming"];}).config.home.file ? v3-test);
    orderIndependentAndModuleDefault = (home {ids = chosenIds;}).config.home.file.v3-test.text == "fixture:23:home-default";
    explicitOverridesDefaults =
      (home {
        ids = chosenIds;
        args = {
          shared = 31;
          homeOnly = "override";
        };
      }).config.home.file.v3-test.text
      == "fixture:31:override";
    commonDefaultUsed = (withModules [commonDefault]).config.home.file.common.text == "17";
    inactiveSectionsStayLazy = (withModules [nixosOnly]).config.home.username == "fixture";
    missingActiveArgumentFails = fails (nixos {ids = chosenIds;}).config.environment.etc.v3-test.text;
    missingEnclosingArgumentFails =
      fails
      (withModules [
        (v3.mkModule {
          name = "required";
          module = {missing}: {home = _: {home.file.required.text = missing;};};
        })
      ]).config.home.file.required.text;
    typeMismatchFails = fails (home {args.userName = 3;}).config.home.username;
    unknownArgumentFails = fails (home {args.typo = true;}).config.home.username;
    derivedHostNameCannotBeOverridden = fails (home {args.hostName = "other";}).config.home.username;
    sharedAssertionPasses = (withModules [(sharedAssertion true)]).config.home.username == "fixture";
    sharedAssertionFails = fails (withModules [(sharedAssertion false)]).config.home.username;
    duplicateModulesFail = fails (v3.mkRegistry {modules = [base base];}).declarations;
    packageNames = builtins.attrNames exports.packages == ["example" "example-helper"];
    checkNames = builtins.attrNames exports.checks == ["example"];
    packageCollisionFails = fails ((collision "packages").perSystem {inherit pkgs system;}).packages;
    checkCollisionFails = fails ((collision "checks").perSystem {inherit pkgs system;}).checks;
    independentPackages = exports.packages.example.name == "v3-owned-package";
    discoveryExclusions = builtins.attrNames discovered.declarations == ["discovered" "sibling"];
    discoverySource = discovered.declarations.discovered.source == ./discovery/modules/example.nix;
    discoveredHome = discovered.homeConfigurations.discovered.config.home.username == "discovered";
    homeOnlyNixosWrapper =
      (nixos {
        ids = chosenIds;
        args.systemOnly = "system-value";
      }).config.home-manager.users.fixture.home.file.v3-test.text
      == "fixture:23:home-default";
    distinctSectionContexts =
      (nixos {
        ids = chosenIds;
        args.systemOnly = "system-value";
      }).config.environment.etc.v3-test.text
      == "test-system:23:system-value";
    directHomeConsumer =
      (inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          userName = "direct";
          shared = 49;
        };
        modules = [registry.homeModules.base registry.homeModules.example];
      }).config.home.file.v3-test.text
      == "direct:49:home-default";
    noImplicitContext = (withModules [noImplicitArgs]).config.home.file.explicit.text == "FIXTURE";
    sectionDefaultOverridesCommon = (withModules [sectionDefaults]).config.home.file.section-defaults.text == "29";
    trueHomeOnlyNixosWrapper =
      (v3.mkHost {
        modules = [base onlyHome];
        inherit commonArgs system;
        name = "home-only-wrapper";
        role = "nixos";
      }).config.home-manager.users.fixture.home.file.only-home.text
      == "fixture";
    directNixosConsumer =
      (inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          userName = "external";
          shared = 41;
          systemOnly = "external-system";
        };
        modules = [registry.nixosModules.base registry.nixosModules.example];
      }).config.home-manager.users.external.home.file.v3-test.text
      == "external:41:home-default";
    assertionOnlyModuleApplies =
      fails
      (withModules [
        (v3.mkModule {
          name = "assertion-only";
          assertions = _: [
            {
              assertion = false;
              message = "assertion-only fixture";
            }
          ];
        })
      ]).config.home.username;
    systemAssertionStaysInactive =
      (withModules [
        (v3.mkModule {
          name = "system-assertion";
          module = _: {
            nixos = _: {
              assertions = [
                {
                  assertion = false;
                  message = "system-only fixture";
                }
              ];
            };
            home = _: {};
          };
        })
      ]).config.home.username
      == "fixture";
    missingUnusedRequiredFails =
      fails
      (withModules [
        (v3.mkModule {
          name = "unused-required";
          module = _: {home = {requiredButUnused}: {home.file."argument-name".text = builtins.head (builtins.attrNames {inherit requiredButUnused;});};};
        })
      ]).config.home.username;
    nestedCommonTypeFails =
      fails
      (v3.mkHost {
        modules = [
          base
          (v3.mkModule {
            name = "nested-type";
            module = {list}: {home = _: {home.file."list".text = builtins.toJSON list;};};
          })
        ];
        commonArgs =
          commonArgs
          // {
            list = {
              type = lib.types.listOf lib.types.int;
              description = "Integers only.";
            };
          };
        args.list = ["wrong"];
        name = "nested-types";
        role = "home";
        inherit system;
      }).config.home.file.list.text;
    hostDependentPackageFails =
      fails
      ((v3.mkRegistry {
        modules = [
          (v3.mkModule {
            name = "bad-package";
            packages.default = _: pkgs.hello;
          })
        ];
      }).perSystem {inherit pkgs system;}).packages.bad-package;
    invalidRoleFails = fails (home {role = "invalid";}).config.home.username;
    unselectedRequirementsStayLazy =
      (v3.mkHost {
        modules = [base (nixosOnly // {ids = ["unselected"];})];
        inherit commonArgs system;
        name = "unselected-host";
        role = "nixos";
      }).config.networking.hostName
      == "unselected-host";
    equalIdSetsSelectTogether =
      (withModules [commonDefault onlyHome]).config.home.file ? common
      && (withModules [commonDefault onlyHome]).config.home.file ? only-home;
    extraHomeManagerUserFails =
      fails
      (v3.mkHost {
        modules = [
          base
          (v3.mkModule {
            name = "extra-user";
            module = _: {nixos = _: {home-manager.users.second.home.stateVersion = "26.05";};};
          })
        ];
        inherit commonArgs system;
        name = "too-many-users";
        role = "nixos";
      }).config.networking.hostName;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) tests);
in {
  diagnostics = {
    missing = (nixos {ids = chosenIds;}).config.environment.etc.v3-test.text;
    unused = (home {args.systemOnly = "unused";}).config.home.username;
    unknown = (home {args.misspelled = true;}).config.home.username;
    type = (home {args.userName = 7;}).config.home.username;
    assertion = (withModules [(sharedAssertion false)]).config.home.username;
  };
  results =
    if failures == []
    then tests
    else throw "Failed modules-v3 fixtures: ${lib.concatStringsSep ", " failures}";
  build =
    builtins.deepSeq (
      if failures == []
      then true
      else throw "Failed modules-v3 fixtures"
    ) (pkgs.runCommand "modules-v3-fixtures" {} ''
      test "$(cat ${exports.packages.example})" = owned
      test -e ${exports.checks.example}
      touch "$out"
    '');
}
