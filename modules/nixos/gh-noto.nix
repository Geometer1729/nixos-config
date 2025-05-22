{ config, lib, pkgs, ... }:

let
  script = pkgs.writeShellScriptBin "ci-pr-notify" ''
    #!/bin/sh
    REPOS=("o1-labs/o1js")
    STATUS_FILE="/tmp/ci_statuses.txt"

    [ ! -f "$STATUS_FILE" ] && touch "$STATUS_FILE"

    for REPO in "''${REPOS[@]}"; do
      PRS=$(gh pr list -R "$REPO" --author "@me" --state open --json number,headRefName)
      echo "$PRS" | jq -r '.[] | "\(.number) \(.headRefName)"' | while read -r PR_NUMBER BRANCH; do
        SHA=$(gh api "repos/$REPO/commits/$BRANCH" | jq -r '.sha')
        STATE=$(gh api "repos/$REPO/commits/$SHA/status" | jq -r '.state')
        KEY="\$\{REPO}#\$\{PR_NUMBER}"
        PREV_STATE=$(grep "^$KEY:" "$STATUS_FILE" | cut -d: -f2)

        if [[ "$STATE" != "$PREV_STATE" && ("$STATE" == "success" || "$STATE" == "failure") ]]; then
          ${pkgs.libnotify}/bin/notify-send "CI $STATE for $REPO PR #$PR_NUMBER"
        fi

        grep -v "^$KEY:" "$STATUS_FILE" > "\$\{STATUS_FILE}.tmp"
        echo "$KEY:$STATE" >> "\$\{STATUS_FILE}.tmp"
        mv "\$\{STATUS_FILE}.tmp" "$STATUS_FILE"
      done
    done
  '';
in
{
  options.ciPrNotify.enable = lib.mkEnableOption "CI PR notification service";

  config = lib.mkIf config.ciPrNotify.enable {
    systemd.user = {
      services.ciPrNotify = {
        Unit.Description = "CI PR Notification Service";
        Service = {
          ExecStart = "${script}/bin/ci-pr-notify";
          Type = "oneshot";
        };
      };

      timers.ciPrNotify = {
        Unit.Description = "Run CI PR notification check every minute";
        Timer = {
          OnCalendar = "*:0/1"; # Every minute
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    environment.systemPackages = [ script ];
  };
}
