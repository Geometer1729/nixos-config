{ config, lib, pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # Enable TCP/IP connections
    enableTCPIP = true;

    # Authentication configuration
    # Local connections use peer authentication
    # TCP/IP connections from localhost use md5 password authentication
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     peer
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
    '';

    # Ensure the database cluster is initialized
    ensureDatabases = [ "bbrian" ];

    # Ensure these users exist
    ensureUsers = [
      {
        name = "bbrian";
        ensureDBOwnership = true;
      }
    ];
  };

  # Add PostgreSQL client tools to system packages
  environment.systemPackages = with pkgs; [
    postgresql_16
  ];
}
