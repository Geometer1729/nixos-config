{ pkgs, ... }:
{
  home.packages = with pkgs; [
    tmate
    tmux
    nix-output-monitor
    nixpkgs-fmt
    nix-inspect
    neovim-remote
    postman # rest-api tool
    nixd # nix lsp
    sqls # sql lsp
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
    moreutils # more gnu utils like sponge
    usbutils

    claude-code

    # Haskell development
    (haskellPackages.ghc.withPackages
      (pkgs: with pkgs; [
        flow
        mtl
        containers
        text
        time
        generics-sop
      ])
    )
    haskellPackages.hoogle
  ];

  # GHC configuration
  home.file.".ghc/ghci.conf".source = ./ghci.repl;
}
