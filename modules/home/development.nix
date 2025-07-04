{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tmate
    tmux
    nix-output-monitor
    nixpkgs-fmt
    neovim-remote
    postman # rest-api tool
    nixd # nix lsp
    okteta # hex editor

    # Command line utilities
    ranger # tui file browser
    arp-scan # network scanner
    cloc # count lines of code
    jq # json tool
    wget
    gh
    just
    expect # provides unbuffer
    unzip
    tldr
    killall
    ripgrep

    # Haskell development
    (haskell.packages.ghc982.ghcWithPackages
      (pkgs: with pkgs; [
        flow
        mtl
        containers
        text
        time
        generics-sop

        xmonad
        xmonad-contrib
      ])
    )
    haskellPackages.hoogle
  ];

  # GHC configuration
  home.file.".ghc/ghci.conf".source = ./ghci.repl;
}
