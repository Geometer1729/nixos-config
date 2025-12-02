{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      slack
    ];

  programs.ssh.matchBlocks =
    let
      me = {
        identityFile = "/home/bbrian/.ssh/id_ed25519";
      };
    in
    {
      vault = me // { hostname = "vault.geosurge.ai"; user = "doma"; };
      geomancer = me // { hostname = "geomancer.geosurge.ai"; user = "operator"; };
    };
}
