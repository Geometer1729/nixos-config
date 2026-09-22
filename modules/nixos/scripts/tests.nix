{ lib, pkgs, runCommand, ... }:
let
  definitions = {
    directory = ./tests;
    extras = [ (pkgs.writeShellScriptBin "choice" "echo group") ];
    runtimeEnv = {
      GREETING = "default";
    };
  };
  evaluate = hasGui: adapter: (lib.evalModules {
    specialArgs = {
      inherit pkgs;
      machine = { inherit hasGui; };
    };
    modules = [
      {
        options.home.packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
        options.environment.systemPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
        };
        options.home-manager.sharedModules = lib.mkOption {
          type = lib.types.listOf lib.types.deferredModule;
          default = [ ];
        };
      }
      adapter
      {
        scripts.sample = definitions;
        scripts.disabled-group = definitions // { enable = false; };
      }
      {
        scripts.sample = {
          extras = [ pkgs.findutils ];
          runtimeEnv.EXPECT_NOTIFY = lib.boolToString hasGui;
          overrides = {
            greeting = {
              extras = [ (pkgs.writeShellScriptBin "choice" "echo command") ];
              runtimeEnv.GREETING = "overridden";
            };
            disabled.enable = false;
            renamed = {
              source = ./tests/disabled.sh;
              enable = false;
            };
          };
        };
      }
    ];
  }).config;
  system = evaluate false ./.;
  guiSystem = evaluate true ./.;
  # Exercise the Home Manager module registered by the NixOS entry point.
  home = evaluate false { imports = system.home-manager.sharedModules; };
  guiHome = evaluate true { imports = guiSystem.home-manager.sharedModules; };
in
assert builtins.attrNames home.scripts.sample.packages == [ "disabled" "greeting" "renamed" ];
assert home.home.packages == [ home.scripts.sample.packages.greeting ];
assert home.environment.systemPackages == [ ];
assert system.environment.systemPackages == [ system.scripts.sample.packages.greeting ];
assert system.home.packages == [ ];
assert home.scripts.sample.packages.greeting == system.scripts.sample.packages.greeting;
assert guiHome.scripts.sample.packages.greeting == guiSystem.scripts.sample.packages.greeting;
assert lib.elem pkgs.findutils home.scripts.sample.extras;
assert builtins.length home.scripts.sample.extras == 2;
runCommand "script-modules" { } ''
  # Wrappers must work with the default toolbox and automatic lib/ discovery,
  # without an ambient PATH. The fixture checks notify-send in both GUI modes.
  # Per-command packages must precede group packages (e.g. a wrapper and its upstream).
  test "$(PATH= ${lib.getExe home.scripts.sample.packages.greeting})" = '"overridden:from-library:command"'
  test "$(PATH= ${lib.getExe system.scripts.sample.packages.greeting})" = '"overridden:from-library:command"'
  test "$(PATH= ${lib.getExe guiHome.scripts.sample.packages.greeting})" = '"overridden:from-library:command"'
  # Disabled entries still expose packages; explicit source overrides allow renaming.
  test "$(PATH= ${lib.getExe home.scripts.sample.packages.disabled})" = disabled
  test "$(PATH= ${lib.getExe home.scripts.sample.packages.renamed})" = disabled
  test "$(PATH= ${lib.getExe home.scripts.disabled-group.packages.disabled})" = disabled
  touch "$out"
''
