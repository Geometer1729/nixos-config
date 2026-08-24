{ flake, pkgs, config, lib, ... }:
# OpenCode V2 is still incomplete, so this config intentionally contains temporary hacks.
# Delete them in favor of equivalent native features as those land; they are not compatibility requirements.
let
  inherit (flake) inputs;
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
  };
  opencode1 = pkgs.writeShellApplication {
    name = "opencode1";
    runtimeEnv = {
      # opencode-vim's broad peer ranges otherwise resolve to a conflicting OpenTUI tree.
      NPM_CONFIG_FORCE = "true";
      PINENTRY_USER_DATA = "gui";
    };
    text = ''
      exec ${unstable.opencode}/bin/opencode "$@"
    '';
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

      install -Dm755 bin/opencode2 $out/bin/opencode2
      # OpenTUI dlopens libwayland-client.so.0 by soname for host clipboard reads,
      # and Bun extracts its copy at runtime where autoPatchelfHook never sees it.
      wrapProgram $out/bin/opencode2 \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ripgrep ]} \
        --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.wayland ]} \
        --set NPM_CONFIG_FORCE true \
        --set OPENCODE_DISABLE_AUTOUPDATE true \
        --set PINENTRY_USER_DATA gui

      runHook postInstall
    '';

    meta = {
      description = "OpenCode v2 next-channel preview";
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

  home.packages = with pkgs; [
    config.services.meridian.package
    libnotify
    opencode
    opencode1
    opencode2
  ];
  home.sessionVariables.OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  services.meridian = {
    enable = true;
    environment.CLAUDE_CONFIG_DIR = "${config.home.homeDirectory}/.claude-work";
  };

  xdg.configFile = {
    "opencode/AGENTS.md".source = ./AGENTS.md;
    # Add global skills as ./skills/<id>/SKILL.md.
    "opencode/skills" = {
      source = ./skills;
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
      mcp.slack = {
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
      model = "openai/gpt-5.6-sol";
      plugin = [ config.services.meridian.opencode.pluginPath ];
      plugins = [
        {
          package = "file://${config.xdg.configHome}/opencode/plugins/configured/lsp-v2.js";
          options.servers = lspServers;
        }
      ];
      provider.anthropic.options = {
        apiKey = "x";
        baseURL = "http://127.0.0.1:3456";
      };
      permission = import ./permissions.nix { inherit config; };
    };
  }
  // import ./plugins { inherit lib; };
}
