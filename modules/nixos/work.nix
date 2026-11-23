{ config, lib, pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;

    # Enable TCP/IP connections
    enableTCPIP = true;

    # Authentication configuration
    # Local connections use peer authentication
    # grim's local dev `.env` connects as `fake` over TCP; trust only that
    # role on its own database so no password lands in the Nix store.
    # Other TCP/IP connections from localhost use md5 password authentication
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     peer
      host    fake            fake            127.0.0.1/32            trust
      host    fake            fake            ::1/128                 trust
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
    '';

    # Ensure the database cluster is initialized
    ensureDatabases = [ "bbrian" "fake" ];

    # Ensure these users exist
    ensureUsers = [
      {
        name = "bbrian";
        ensureDBOwnership = true;
        ensureClauses = {
          superuser = true;
          createrole = true;
          createdb = true;
        };
      }
      {
        # grim-monolith's glacial-wall dev database; apply its schema with
        # `pnpm --filter @geoSurge/shared-db db:push`.
        name = "fake";
        ensureDBOwnership = true;
      }
    ];
  };

  # shared-db's migrations create pg_trgm, which the non-superuser `fake`
  # role cannot do itself.
  systemd.services.postgresql-setup.script = lib.mkAfter ''
    psql -d fake -v ON_ERROR_STOP=1 -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm'
  '';

  # Keep migrated schemas and dev data across reboots.
  environment.persistence."/persist/system" = lib.mkIf (config ? environment.persistence) {
    directories = [
      { directory = "/var/lib/postgresql"; user = "postgres"; group = "postgres"; mode = "0750"; }
    ];
  };

  # glacial-wall defaults to redis://localhost:6379. It is only a cache, so
  # nothing is saved to disk.
  services.redis.servers."" = {
    enable = true;
    port = 6379;
    save = [ ];
  };

  # Add PostgreSQL client tools to system packages
  environment.systemPackages = with pkgs; [
    postgresql_18
  ];
}
