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
    initialization = {
      # Its cargo check only reruns on save, which the plugin never sends, so
      # its errors went stale. Agents run cargo themselves.
      checkOnSave = false;
      # Missing match arms. rust-analyzer analyses each workspace crate once,
      # with cfg(test) on, so its dependents see #[cfg(test)] enum variants
      # and get false errors. cargo still reports real ones.
      diagnostics.disabled = [ "E0004" ];
    };
  };
  typescript = {
    command = [ "typescript-language-server" "--stdio" ];
    extensions = [ ".ts" ".tsx" ];
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
