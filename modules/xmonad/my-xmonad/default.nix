inputs@{ self, nixpkgs, flake-parts, ... }:
{
  outputs={
    flake-parts.lib.mkFlake { inherit self; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ inputs.haskell-flake.flakeModule ];
      perSystem = { self', pkgs, ... }: {
        haskellProjects.default = {
          name = "my-xmonad";  # assumes myproject.cabal
          root = ./.;
          buildTools = hp: { fourmolu = hp.fourmolu; hls = hp.haskell-language-server; };
          # source-overrides = { };
          # overrides = self: super: { };
          hlintCheck.enable = true;
          hlsCheck.enable = true;
        };
      };
    };
  };
}
