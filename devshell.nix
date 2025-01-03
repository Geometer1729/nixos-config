{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      name = "nixos-unified-template-shell";
      meta.description = "Shell environment for modifying this Nix configuration";
      packages = with pkgs; [
        # TODO xmonad devShell
        pkgs.sumneko-lua-language-server # for nvim config stuff
        just
        nixd
      ];
    };
  };
}
