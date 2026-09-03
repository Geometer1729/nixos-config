{
  imports = [ ./cache.nix ];

  nix.settings.system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  nix.sshServe.enable = true;
}
