{
  nixd = {
    command = [ "nixd" ];
    extensions = [ ".nix" ];
  };
  "lua-ls" = {
    command = [ "lua-language-server" ];
    extensions = [ ".lua" ];
  };
  bash = {
    command = [ "bash-language-server" "start" ];
    extensions = [ ".sh" ".bash" ".zsh" ".ksh" ];
  };
  rust = {
    command = [ "rust-analyzer" ];
    extensions = [ ".rs" ];
  };
  # Resolve HLS from the project's dev shell so its GHC version matches.
  hls = {
    command = [ "haskell-language-server" "--lsp" ];
    extensions = [ ".hs" ".lhs" ];
  };
  "yaml-ls" = {
    command = [ "yaml-language-server" "--stdio" ];
    extensions = [ ".yaml" ".yml" ];
  };
}
