{ flake, config, machine, pkgs, lib, ... }:
{
  scripts.nvim = {
    directory = ./.;
    extras = [ pkgs.libnotify config.programs.nixvim.build.package ]
      ++ lib.optional machine.hasGui pkgs.ghostty;
  };

  stylix.targets.nixvim = {
    enable = true;
    #plugin = "base16-nvim";
    transparentBackground = {
      main = true;
      signColumn = true;
    };
  };
  programs.nixvim =
    (import ./nixvim.nix {
      inherit pkgs lib;
      nixpkgsSource = flake.inputs.nixpkgs;
      pluginSources = {
        inherit (flake.inputs)
          telescope-vimwiki-nvim
          nvim-luaref
          ocaml-nvim
          recover-vim
          ;
      };
    })
    // { enable = true; };

  # Start the deployed nvim on the deployed config files; any startup output
  # (Lua errors, deprecation warnings) fails the build. nixvim's own
  # `build.test` can't do this under Home Manager: its nvim runs without init.lua.
  home.checks = [
    (pkgs.runCommand "nvim-config-check" { nativeBuildInputs = [ config.programs.nixvim.build.package ]; } ''
      export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR/config XDG_DATA_HOME=$TMPDIR/data
      export XDG_STATE_HOME=$TMPDIR/state XDG_CACHE_HOME=$TMPDIR/cache
      ${lib.concatStrings (lib.mapAttrsToList (name: file: ''
        mkdir -p "$(dirname "$XDG_CONFIG_HOME/${name}")"
        ln -s ${file.source} "$XDG_CONFIG_HOME/${name}"
      '') (lib.filterAttrs (name: _: lib.hasPrefix "nvim/" name) config.xdg.configFile))}
      if ! output=$(nvim -mn --headless +q 2>&1 >/dev/null) || [[ -n $output ]]; then
        echo "$output" >&2
        exit 1
      fi
      touch $out
    '')
  ];

}
