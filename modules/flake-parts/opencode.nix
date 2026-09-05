{
  perSystem = { pkgs, lib, ... }: {
    checks.opencode-plugins = (import ../home/opencode/plugins/package.nix {
      inherit lib pkgs;
    }).check;
  };
}
