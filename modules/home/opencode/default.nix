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
      wrapProgram $out/bin/opencode2 \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ripgrep ]} \
        --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.wayland ]} \
        --set NPM_CONFIG_FORCE true \
        --set DIRENV_NO_TMUX_RENAME true \
        --set OPENCODE_DISABLE_AUTOUPDATE true \
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
  lspServers = import ./lsp-servers.nix;
in
{
  imports = [ inputs.meridian.homeModules.default ];

  # Plugin typecheck/tests, then load the real plugins under the deployed config.
  home.checks = [
    pluginBuild.check
    (import ./checks/load.nix { inherit lib pkgs; home = config; })
  ];

  home.packages = with pkgs; [
    config.services.meridian.package
  ] ++ lib.optionals machine.hasGui [ libnotify notify ] ++ [
    opencode2
  ];
  home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  programs.opencode = {
    enable = true;
    package = opencode;
  };
  stylix.targets.opencode.enable = true;

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

  services.meridian = {
    enable = true;
    environment.CLAUDE_CONFIG_DIR = "${config.home.homeDirectory}/.claude-work";
    # Override Meridian's bundled Nixpkgs Claude with the one used by the CLI.
    environment.MERIDIAN_CLAUDE_PATH = lib.getExe config.programs.claude-code.package;
    # The quota API requires explicit paths (it ignores CLAUDE_CONFIG_DIR).
    # Keep the existing default profile ID so SDK sessions retain their owner.
    environment.MERIDIAN_DEFAULT_PROFILE = "default";
    # Meridian's module emits Environment= literally; systemd must preserve the
    # JSON quotes rather than interpreting them as unit-file quoting.
    environment.MERIDIAN_PROFILES = lib.escapeShellArg (builtins.toJSON [
      { id = "default"; claudeConfigDir = "${config.home.homeDirectory}/.claude-work"; }
      { id = "personal"; claudeConfigDir = "${config.home.homeDirectory}/.claude-personal"; }
    ]);
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

    "meridian/sdk-features.json" = {
      force = true;
      text = builtins.toJSON {
        opencode = {
          clientSystemPrompt = false;
          codeSystemPrompt = true;
        };
      };
    };

    "opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = false;
      lsp = lspServers;
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
      };
      #model = "openai/gpt-6-astra";
      model = "anthropic/claude-opus-5-5#xhigh";
      agents = {
        build.model = "anthropic/claude-opus-5-5#xhigh";
        explore.model = "openai/gpt-6-sol#xhigh";
        expert = {
          description = "Handles architecture, difficult diagnosis, and independent code review";
          mode = "subagent";
          model = "anthropic/claude-fable-5-1#xhigh";
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
        { package = "file://${plugins}/meridian"; }
      ] ++ lib.optionals machine.hasGui [{
        package = "file://${plugins}/notifications";
        options.command = "${notify}/bin/opencode-notify";
        options.focusCommand = "${focus}/bin/opencode-focus";
      }
        {
          package = "file://${plugins}/usage";
          options.timezone = "America/New_York";
        }];
      provider = {
        anthropic.options = {
          apiKey = "x";
          baseURL = "http://127.0.0.1:3456";
        };
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
