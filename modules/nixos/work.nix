{ pkgs, ... }:
let
  # Probably don't need this but it's at least nice as an app image template
  #ledger-live-desktop =
  #  let
  #    version = "2.81.2";
  #  in pkgs.appimageTools.wrapType1
  #  {
  #    name = "ledger-live-desktop";
  #    inherit version;
  #    src = pkgs.fetchurl {
  #      url = "https://download.live.ledger.com/ledger-live-desktop-${version}-linux-x86_64.AppImage";
  #      sha256 = "sha256-dnlIIOOYmCN209avQFMcoekB7nJpc2dJnS2OBI+dq7E=";
  #    };
  #  };
  #clorio =
  #  let
  #    version = "2.1.2";
  #  in pkgs.appimageTools.wrapType1
  #  {
  #    name = "clorio";
  #    inherit version;
  #    src = pkgs.fetchurl {
  #      url = "https://github.com/nerdvibe/clorio-client/releases/download/v${version}/Clorio.Wallet-${version}.AppImage";
  #      sha256 = "sha256-U/4lOkLhnii40WqVUwFHota9Hu3g4vjSiMFW+mgoGN4=";
  #    };
  #  };

in
{
  services.postgresql = {
    enable = true;
    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser  ADDRESS METHOD
      local all all trust
      host  all all 0.0.0.0/0 trust
      host  all all ::0/0 trust
    '';
    # this probably doesn't help either tbh
    settings = {
      listen_addresses = pkgs.lib.mkOverride 10 "*";
    };
    # doesn't work
    #initialScript = pkgs.writeText "init-sql-script"
    #''
    #  alter user postgres with password 'postgres';
    #'';
  };
  #users.users.postgres.password = "postgres";

  #users.users.postgres.password = "";

  #virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "bbrian" ];
  #virtualisation.vmware.host.enable = true;
  #virtualisation.vmware.guest.enable = true;
  virtualisation.docker.enable = true;
  users.users.bbrian.extraGroups = [ "docker" ];
  #users.users.bbrian.packages = [ ledger-live-desktop clorio ];
  nix.settings = {
    extra-substituters = [ "https://storage.googleapis.com/mina-nix-cache" ];
    extra-trusted-public-keys = [
      "nix-cache.minaprotocol.org:fdcuDzmnM0Kbf7yU4yywBuUEJWClySc1WIF6t6Mm8h4="
      "nix-cache.minaprotocol.org:D3B1W+V7ND1Fmfii8EhbAbF1JXoe2Ct4N34OKChwk2c="
      "mina-nix-cache-1:djtioLfv2oxuK2lqPUgmZbf8bY8sK/BnYZCU2iU5Q10="
    ];
  };

}
