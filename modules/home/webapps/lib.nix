{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.webapps;

  fetchIcon = url: pkgs.fetchurl {
    inherit url;
    sha256 = "01kcyw28iayd1lgw7jnjv7bv87nvwsx3fkbp9rz0fq16b5w696nz";
  };

  mkWebapp = name: webapp:
    let
      iconPath =
        if hasPrefix "http" webapp.icon
        then toString (fetchIcon webapp.icon)
        else webapp.icon;
    in
    pkgs.writeTextFile {
      name = "${name}.desktop";
      destination = "/share/applications/${name}.desktop";
      text = ''
        [Desktop Entry]
        Version=1.0
        Name=${webapp.name}
        Comment=${webapp.description or webapp.name}
        Exec=${pkgs.ungoogled-chromium}/bin/chromium --app="${webapp.url}" --class="${name}-webapp"
        Terminal=false
        Type=Application
        Icon=${iconPath}
        StartupNotify=true
        Categories=Network;WebBrowser;
        ${optionalString (webapp.mimeTypes != []) "MimeType=${concatStringsSep ";" webapp.mimeTypes};"}
        ${optionalString webapp.noDisplay "NoDisplay=true"}
      '';
    };

  webappPackages = mapAttrsToList mkWebapp cfg.apps;

in
{
  options.programs.webapps = {
    enable = mkEnableOption "web applications";

    apps = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Display name of the web application";
          };

          url = mkOption {
            type = types.str;
            description = "URL to launch";
            example = "https://perplexity.ai";
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Description of the web application";
          };

          icon = mkOption {
            type = types.str;
            default = "chromium";
            description = "Icon name or path for the application";
          };

          mimeTypes = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "MIME types this webapp can handle";
          };

          noDisplay = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to hide this webapp from application menus";
          };
        };
      });
      default = { };
      description = "Web applications to create desktop entries for";
    };
  };

  config = mkIf cfg.enable {
    home.packages = webappPackages;
  };
}
