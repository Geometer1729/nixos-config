{ flake, pkgs, config, machine, lib, ... }:
# OpenCode V2 is still incomplete, so this config intentionally contains temporary hacks.
# Delete them in favor of equivalent native features as those land; they are not compatibility requirements.
let
  inherit (flake) inputs;
  pluginBuild = import ./plugins/package.nix { inherit lib pkgs; };
  plugins = pluginBuild.package;
  notify = pkgs.writeShellApplication {
    name = "opencode-notify";
    runtimeInputs = with pkgs; [ coreutils jq libnotify mako socat util-linux ];
    text = builtins.readFile ./notify.sh;
  };
  focus = pkgs.writeShellApplication {
    name = "opencode-focus";
    runtimeInputs = with pkgs; [ coreutils hyprland jq procps tmux ];
    text = builtins.readFile ./focus.sh;
  };
  opencode2Npm = builtins.fromJSON (builtins.readFile inputs.opencode2-npm);
  opencode2 = pkgs.stdenv.mkDerivation {
    pname = "opencode2";
    inherit (opencode2Npm) version;
    src = pkgs.fetchurl {
      url = opencode2Npm.dist.tarball;
      hash = opencode2Npm.dist.integrity;
    };
    sourceRoot = "package";

    nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
    dontBuild = true;
    dontStrip = true; # Stripping removes Bun's embedded application payload.
    installPhase = ''
      runHook preInstall

      install -Dm755 bin/opencode $out/bin/opencode2
      # OpenTUI dlopens libwayland-client.so.0 by soname for host clipboard reads,
      # and Bun extracts its copy at runtime where autoPatchelfHook never sees it.
      # OpenTUI disables OSC 8 links under tmux, so wrapped URLs only open their
      # clicked row; tmux forwards them via the hyperlinks terminal feature.
      wrapProgram $out/bin/opencode2 \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ripgrep ]} \
        --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.wayland ]} \
        --set NPM_CONFIG_FORCE true \
        --set DIRENV_NO_TMUX_RENAME true \
        --set OPENCODE_DISABLE_AUTOUPDATE true \
        --set FORCE_HYPERLINK 1 \
        --set OPENCODE_CLAUDE_PATH ${lib.getExe config.scripts.claude.packages.claude-agent} \
        --set PINENTRY_USER_DATA ${if machine.hasGui then "gui" else "curses"}

      runHook postInstall
    '';

    meta = {
      description = "OpenCode v2";
      homepage = "https://github.com/anomalyco/opencode/tree/v2";
      license = pkgs.lib.licenses.mit;
      mainProgram = "opencode2";
      platforms = [ "x86_64-linux" ];
    };
  };
  opencode = pkgs.writeShellApplication {
    name = "opencode";
    text = ''
      exec ${opencode2}/bin/opencode2 "$@"
    '';
  };
  serve = pkgs.writeShellApplication {
    name = "opencode-serve";
    runtimeInputs = [ opencode2 pkgs.jq pkgs.systemd config.programs.zsh.package ];
    text = builtins.readFile ./serve.sh;
  };
  # Plugins call Hyprland, so wait for the session environment where there is one.
  serveTarget = if machine.hasGui then "graphical-session.target" else "default.target";
  lspServers = import ./lsp-servers.nix;
in
{
  # Plugin typecheck/tests, then load the real plugins under the deployed config.
  home.checks = [
    pluginBuild.check
    (import ./checks/load.nix { inherit lib pkgs; home = config; })
  ];

  home.packages = with pkgs; lib.optionals machine.hasGui [ libnotify notify ] ++ [
    opencode2
  ];
  home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  programs.opencode = {
    enable = true;
    package = opencode;
  };
  stylix.targets.opencode.enable = true;

  keyHelp.opencode = {
    match.process = "(^|/)opencode2( |$)";
    binds = [{
      key = "ctrl+p";
      description = "Command palette (lists binds)";
      keys = [ "C-p" ];
    }];
  };

  systemd.user.services.opencode-serve = {
    Unit = {
      Description = "Start the OpenCode server for paired apps";
      After = [ serveTarget ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${serve}/bin/opencode-serve";
    };
    Install.WantedBy = [ serveTarget ];
  };

  services.mako.settings = lib.mkIf machine.hasGui {
    "app-name=OpenCode category=opencode.waiting" = {
      width = 500;
      height = 900;
      default-timeout = 0;
      ignore-timeout = true;
      history = false;
      on-button-left = "exec ${notify}/bin/opencode-notify --focus \"$id\"";
    };
  };

  xdg.configFile = {
    "opencode/AGENTS.md".source = ./AGENTS.md;
    "opencode/cli.json" = {
      force = true;
      text = builtins.toJSON {
        "$schema" = "https://opencode.ai/v2/cli.json";
        animations = true;
        attention.sound = true;
        attention.notifications = !machine.hasGui;
        plugins = [ "file://${plugins}/vim" "file://${plugins}/auto-tabs" ]
          ++ lib.optional machine.hasGui {
          package = "file://${plugins}/notifications";
          options.focusCommand = "${focus}/bin/opencode-focus";
        };
        diffs.wrap = "word";
        session = {
          markdown = "rendered";
          scrollbar = false;
          sidebar = "auto";
          thinking = "hide";
        };
        tabs = {
          enabled = true;
          layout = "horizontal";
        };
        theme = {
          mode = "dark";
          name = "stylix";
        };
      };
    };
    # Add global skills as ./skills/<id>/SKILL.md.
    "opencode/skills" = {
      source = ./skills;
      recursive = true;
    };
    "opencode/commands" = {
      source = ./commands;
      recursive = true;
    };

    "opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = false;
      lsp = lspServers;
      references.conf = {
        path = "${config.home.homeDirectory}/conf";
        description = builtins.concatStringsSep " " [
          "Declarative NixOS/home-manager configuration for this machine, including OpenCode itself"
          "(MCP servers, plugins, permissions, skills, AGENTS.md) and the dev tools agents rely on."
          "Read it when the environment behaves unexpectedly."
          "When OpenCode, an MCP server, or a dev tool is broken or misconfigured, fixing it here is wanted:"
          "follow its AGENTS.md and propose the change rather than working around the breakage."
        ];
      };
      mcp = lib.optionalAttrs machine.hasGui {
        slack = {
          type = "remote";
          url = "https://mcp.slack.com/mcp";
          # Slack requires MCP clients to be backed by a registered Slack app
          # (no dynamic client registration). Read-only user scopes only.
          oauth = {
            clientId = "{file:/run/secrets/slack_mcp_client_id}";
            clientSecret = "{file:/run/secrets/slack_mcp_client_secret}";
            scope = builtins.concatStringsSep " " [
              "search:read.public"
              "search:read.private"
              "search:read.mpim"
              "search:read.im"
              "search:read.files"
              "search:read.users"
              "files:read"
              "emoji:read"
              "channels:history"
              "groups:history"
              "mpim:history"
              "im:history"
              "channels:read"
              "groups:read"
              "mpim:read"
              "users:read"
              "users:read.email"
              "canvases:read"
            ];
          };
        };
        # Desktop-only browser tools can't reach the TUI; this is the TUI's browser.
        playwright = {
          type = "local";
          # Snapshots and screenshots otherwise land in the session's working directory.
          command = [ (lib.getExe pkgs.playwright-mcp) "--isolated" "--output-dir" "/tmp/playwright-mcp" ];
        };
      };
      #model = "openai/gpt-6-astra";
      model = "claude-agent/opus#xhigh";
      agents = {
        build.model = "claude-agent/opus#xhigh";
        explore.model = "openai/gpt-6-sol#xhigh";
        title.model = "openai/gpt-6-luna";
        expert = {
          description = "Handles architecture, difficult diagnosis, and independent code review";
          mode = "subagent";
          model = "claude-agent/fable#xhigh";
          permissions = [
            {
              action = "edit";
              resource = "*";
              effect = "deny";
            }
          ];
        };
      };
      plugins = [
        {
          # The loader caches canonical paths. Mutable Home Manager symlinks can
          # silently lose registrations after a generation change and reload.
          package = "file://${plugins}/lsp";
          options.servers = lspServers;
        }
      ] ++ lib.optionals machine.hasGui [{
        package = "file://${plugins}/notifications";
        options.command = "${notify}/bin/opencode-notify";
        options.focusCommand = "${focus}/bin/opencode-focus";
        # Sessions here are hidden while `notification-center work` mutes them.
        options.workDirectory = "${config.home.homeDirectory}/Code/work";
      }
        {
          package = "file://${plugins}/usage";
          options.timezone = "America/New_York";
        }];
      provider = {
        openai.models."gpt-6-astra" = {
          modelID = "gpt-6-astra";
          name = "GPT-6 Astra";
          capabilities = {
            tools = true;
            input = [ "text" "image" ];
            output = [ "text" ];
          };
          limit = {
            context = 1050000;
            output = 128000;
          };
          variants = map
            (reasoningEffort: {
              id = reasoningEffort;
              settings = { inherit reasoningEffort; };
            })
            [ "low" "medium" "high" "xhigh" "max" ];
        };
      };
      permission = import ./permissions.nix { inherit config; };
    };
  };
}
