# Parse the generated Hyprland config with the Hyprland it will run under,
# so option renames/removals in updates fail `nix flake check` before deploy.
{ runCommand, hyprland, config }:
runCommand "hyprland-config-check" { nativeBuildInputs = [ hyprland ]; } ''
  export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run
  mkdir -p "$XDG_RUNTIME_DIR"
  Hyprland --verify-config -c ${config}
  touch $out
''
