{ flake, config, lib, pkgs, ... }:
let
  inherit (flake) inputs;
  scheduleReboot = pkgs.writeShellScriptBin "schedule-balrog-reboot" ''
    set -euo pipefail
    export TZ=America/New_York

    now=$(${pkgs.coreutils}/bin/date +%s)
    next=$(${pkgs.coreutils}/bin/date -d "today 02:00" +%s)
    if (( next <= now )); then
      next=$(${pkgs.coreutils}/bin/date -d "tomorrow 02:00" +%s)
    fi

    unit="balrog-reboot-$next"
    if ${pkgs.systemd}/bin/systemctl is-active --quiet "$unit.timer"; then
      echo "Reboot already scheduled for $(${pkgs.coreutils}/bin/date -d "@$next")"
      exit 0
    fi

    ${pkgs.systemd}/bin/systemd-run \
      --unit="$unit" \
      --description="Reboot balrog after cache update" \
      --on-calendar="*-*-* 02:00:00 America/New_York" \
      --timer-property=AccuracySec=1s \
      --collect \
      ${pkgs.systemd}/bin/systemctl reboot
    echo "Reboot scheduled for $(${pkgs.coreutils}/bin/date -d "@$next")"
  '';
in
{
  imports = [
    inputs.self.nixosModules.base
    inputs.self.nixosModules.cache
    inputs.self.nixosModules.taskchampion
    inputs.self.nixosModules.useBuilders
    ./hardware.nix
  ];

  networking.hostName = "balrog";
  networking.useDHCP = true;
  machine.hasGui = false;

  home-manager.users.${config.mainUser} = {
    # Keep management tools without enabling workstation hardware authentication.
    imports = [ ../../../modules/nixos/yubikey/home.nix ];
    home.sessionVariables.NH_FLAKE = lib.mkForce "github:Geometer1729/nixos-config";
    programs.git.signing.signByDefault = lib.mkForce false;
  };

  # Samsung SSD 860 EVO 250GB, serial S3YHNX0KB88921Z.
  drive = "/dev/disk/by-id/wwn-0x5002538e40a0ae76";

  services.openssh = {
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
    };
  };

  systemd.services.tailscale-reset-prefs = {
    description = "Apply declarative Tailscale preferences";
    script = ''
      # Initial tailnet authentication is intentionally interactive.
      if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
        exit 0
      fi
      ${pkgs.tailscale}/bin/tailscale up --reset ${lib.escapeShellArgs config.services.tailscale.extraUpFlags}
    '';
  };

  users.users.root = {
    hashedPassword = "!";
  };
  users.users.${config.mainUser} = {
    hashedPassword = "!";
    linger = true;
  };
  users.groups.github-runner = { };
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
  };
  environment.systemPackages = with pkgs; [ git tmux vim wakeonlan ];
  environment.persistence."/persist/system".directories = [
    {
      directory = "/var/lib/github-runner/cache-warmer";
      user = "github-runner";
      group = "github-runner";
      mode = "0700";
    }
    {
      directory = "/var/lib/cache-warmer";
      user = "github-runner";
      group = "github-runner";
      mode = "0750";
    }
  ];

  services.github-runners.cache-warmer = {
    enable = true;
    url = "https://github.com/Geometer1729/nixos-config";
    tokenFile = "/persist/system/secrets/github-runner-token";
    user = "github-runner";
    group = "github-runner";
    extraLabels = [ "balrog" "cache-warmer" ];
    extraPackages = with pkgs; [ netcat-openbsd wakeonlan ];
    serviceOverrides.ReadWritePaths = [ "/var/lib/cache-warmer" ];
  };
  systemd.services.github-runner-cache-warmer.restartIfChanged = false;
  systemd.paths.cache-warmer-activate = {
    description = "Watch for a cache-warmer activation request";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = "/var/lib/cache-warmer/activate";
      Unit = "cache-warmer-activate.service";
    };
  };
  systemd.services.cache-warmer-activate = {
    description = "Activate balrog and schedule its reboot";
    restartIfChanged = false;
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      status_dir=/var/lib/cache-warmer
      rm -f "$status_dir/activate" "$status_dir/activation-success" "$status_dir/activation-failed"
      trap 'printf "Activation failed with exit code %s\n" "$?" > "$status_dir/activation-failed"' ERR

      target=$(${pkgs.coreutils}/bin/readlink -e /var/lib/cache-warmer/balrog)
      case "$target" in
        /nix/store/*-nixos-system-balrog-*) ;;
        *)
          echo "Refusing to activate unexpected path: $target" >&2
          exit 1
          ;;
      esac
      "$target/bin/switch-to-configuration" switch
      ${scheduleReboot}/bin/schedule-balrog-reboot
      printf 'Activated %s\n' "$target" > "$status_dir/activation-success"
    '';
  };

  nix = {
    package = pkgs.nixVersions.stable;
    settings = {
      max-jobs = 2;
      # Preserve this cache server's upstreams rather than substituting from itself.
      substituters = lib.mkForce [ "ssh-ng://bbrian@am" "https://cache.nixos.org/" ];
      trusted-substituters = lib.mkForce [ "ssh-ng://bbrian@am" ];
      trusted-public-keys = lib.mkForce [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "am:Z8PSUn37U1JU2UXWxnfHPpMQDrCcXa3oLMvNCVPUz5s="
      ];
    };
  };

  system.stateVersion = "26.05";
}
