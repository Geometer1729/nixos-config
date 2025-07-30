{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tmate
    tmux
    nix-output-monitor
    nixpkgs-fmt
    neovim-remote
    nixd # nix lsp

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
    moreutils # more gnu utils like sponge

    claude-code

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
  ] ++ lib.optionals (!stdenv.isDarwin) [
    # Linux-only packages
    postman # rest-api tool
    okteta # hex editor
    wmctrl # window manager control tool
  ];

  # GHC configuration
  home.file.".ghc/ghci.conf".source = ./ghci.repl;
}
