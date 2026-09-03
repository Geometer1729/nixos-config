{ flake, lib, pkgs, ... }:
let
  inherit (flake) inputs;
  keys = import ../../../ssh-authorized-keys.nix;
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
      --on-active="$((next - now))s" \
      --timer-property=AccuracySec=1min \
      --collect \
      ${pkgs.systemd}/bin/systemctl reboot
    echo "Reboot scheduled for $(${pkgs.coreutils}/bin/date -d "@$next")"
  '';
in
{
  imports = [
    inputs.disko.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.impermanence.nixosModules.impermanence
    inputs.stylix.nixosModules.stylix
    inputs.self.nixosModules.boot
    inputs.self.nixosModules.cache
    inputs.self.nixosModules.disko
    inputs.self.nixosModules.impermanence
    inputs.self.nixosModules.machine
    inputs.self.nixosModules.stylix
    inputs.self.nixosModules.taskchampion
    inputs.self.nixosModules.useBuilders
    ./hardware.nix
  ];

  networking.hostName = "balrog";
  networking.useDHCP = true;
  hardware.enableRedistributableFirmware = true;
  machine.hasGui = false;

  nixpkgs.overlays = lib.attrValues inputs.self.overlays;
  nixpkgs.config.allowUnfree = true;

  home-manager = {
    backupFileExtension = "bkp";
    useGlobalPkgs = true;
    useUserPackages = true;
    users.bbrian = {
      imports = [ (inputs.self + /configurations/home/bbrian.nix) ];
      programs.git.signing.signByDefault = lib.mkForce false;
    };
  };

  # Samsung SSD 860 EVO 250GB, serial S3YHNX0KB88921Z.
  drive = "/dev/disk/by-id/wwn-0x5002538e40a0ae76";

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  systemd.services.tailscale-reset-prefs = {
    description = "Apply declarative Tailscale preferences";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Initial tailnet authentication is intentionally interactive.
      if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
        exit 0
      fi
      ${pkgs.tailscale}/bin/tailscale up --reset \
        --ssh \
        --accept-routes \
        --accept-dns \
        --operator=bbrian
    '';
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = keys;
  };
  users.users.bbrian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    linger = true;
    openssh.authorizedKeys.keys = keys;
    shell = pkgs.zsh;
  };
  users.groups.github-runner = { };
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
  };
  security.sudo.wheelNeedsPassword = false;
  security.sudo.extraRules = [
    {
      users = [ "github-runner" ];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl start cache-warmer-activate.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${scheduleReboot}/bin/schedule-balrog-reboot";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [ git tailscale tmux vim wakeonlan scheduleReboot ];
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
    serviceOverrides = {
      NoNewPrivileges = false;
      PrivateUsers = false;
      ReadWritePaths = [ "/var/lib/cache-warmer" ];
      RestrictSUIDSGID = false;
    };
  };
  systemd.services.github-runner-cache-warmer.restartIfChanged = false;
  systemd.services.cache-warmer-activate = {
    description = "Activate the balrog closure built by the cache warmer";
    restartIfChanged = false;
    serviceConfig.Type = "oneshot";
    script = ''
      target=$(${pkgs.coreutils}/bin/readlink -e /var/lib/cache-warmer/balrog)
      case "$target" in
        /nix/store/*-nixos-system-balrog-*) ;;
        *)
          echo "Refusing to activate unexpected path: $target" >&2
          exit 1
          ;;
      esac
      exec "$target/bin/switch-to-configuration" switch
    '';
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      max-jobs = 2;
      trusted-users = [ "root" "bbrian" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 21d";
    };
  };

  system.stateVersion = "26.05";
}
