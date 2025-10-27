{ flake, pkgs, config, ... }:
let
  inherit (flake) inputs;
  common = {
    search = {
      default = "ddg";
      order = [ "ddg" ];
      force = true;
      engines = {
        "Hoogle" = {
          urls = [
            {
              template = "https://hoogle.haskell.org/";
              params = [{ name = "hoogle"; value = "{searchTerms}"; }];
            }
          ];
          icon = "https://hoogle.haskell.org/favicon.png";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [ "@h" ];
        };
        "Nix Packages" = {
          urls = [
            {
              template = "https://search.nixos.org/packages";
              params = [{ name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
                { name = "channel"; value = "unstable"; }];
            }
          ];
          icon =
            "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [ "@np" ];
        };
        "Nix Options" = {
          urls = [
            {
              template = "https://search.nixos.org/options";
              params = [{ name = "type"; value = "options"; }
                { name = "query"; value = "{searchTerms}"; }
                { name = "channel"; value = "unstable"; }];
            }
          ];
          icon =
            "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
          definedAliases = [ "@no" ];
        };
        "NixOS Wiki" = {
          urls =
            [{
              template = "https://nixos.wiki/index.php";
              params = [{ name = "search"; value = "{searchTerms}"; }];
            }];
          icon = "https://nixos.wiki/favicon.png";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [ "@nw" ];
        };
        "Homemanager Options" = {
          urls =
            [{
              template = "https://home-manager-options.extranix.com";
              params = [{ name = "query"; value = "{searchTerms}"; }
                { name = "release"; value = "master"; }];
            }];
          icon = "https://nixos.wiki/favicon.png";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [ "@hm" ];
        };
        "AoN" = {
          urls =
            [{
              template = "https://2e.aonprd.com/Search.aspx";
              params = [{ name = "q"; value = "{searchTerms}"; }];
            }];
          icon = "https://2e.aonprd.com/favicon.ico";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [ "@an" ];
        };
        "Minecraft wiki" = {
          urls =
            [{
              template = "https://minecraft.wiki/w/Special:Search";
              params = [{ name = "search"; value = "{searchTerms}"; }];
            }];
          icon = "https://minecraft.wiki/favicon.ico";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [ "@mcw" ];
        };
        "SMBC" = {
          urls =
            [{
              template = "https://www.ohnorobot.com/index.php";
              params = [{ name = "s"; value = "{searchTerms}"; }
                { name = "comic"; value = "137"; }
                { name = "Search"; value = "Search"; }];
            }];
          icon = "https://www.smbc-comics.com/favicon.ico";
          updateInterval = 24 * 60 * 60 * 1000;
          definedAliases = [ "@smbc" ];
        };
        "google".metaData.hidden = true;
        "bing".metaData.hidden = true;
        "ebay".metaData.hidden = true;
        "amazondotcom-us".metaData.hidden = true;
      };
    };
    settings = {
      "browser.sessionstore.resume_from_crash" = true;
      "browser.startup.page" = 3;
      "accessibility.typeaheadfind.enablesound" = false;
      "browser.compactmode.show" = true;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
      "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
      "browser.newtabpage.activity-stream.feeds.topsites" = false;
      "toolkit.telemetry.pioneer-new-studies-available" = false;
      "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      # Toolbar layout: back, forward, firefox-view, urlbar, downloads, signin, extensions, settings
      "browser.uiCustomization.state" = builtins.toJSON {
        placements = {
          widget-overflow-fixed-list = [ ];
          unified-extensions-area = [ ];
          nav-bar = [
            "back-button"
            "forward-button"
            "stop-reload-button"
            "firefox-view-button"
            "urlbar-container"
            "downloads-button"
            "fxa-toolbar-menu-button"
            "unified-extensions-button"
          ];
          toolbar-menubar = [ "menubar-items" ];
          TabsToolbar = [ "tabbrowser-tabs" "new-tab-button" "alltabs-button" ];
          PersonalToolbar = [ "personal-bookmarks" ];
        };
        seen = [
          "save-to-pocket-button"
          "developer-button"
          "screenshot-button"
        ];
        dirtyAreaCache = [ "nav-bar" "PersonalToolbar" "toolbar-menubar" "TabsToolbar" ];
        currentVersion = 23;
        newElementCount = 0;
      };
    };
    userChrome =
      let
        cssTemplate = builtins.readFile ./firefox-userchrome.css;
        # Replace placeholders with actual color values
        replaceColor = placeholder: color: builtins.replaceStrings [ placeholder ] [ color ];
      in
      replaceColor "@base00@" config.lib.stylix.colors.withHashtag.base00 (
        replaceColor "@base01@" config.lib.stylix.colors.withHashtag.base01 (
          replaceColor "@base05@" config.lib.stylix.colors.withHashtag.base05 cssTemplate
        )
      );
    extensions = {
      force = true;
      packages = with inputs.firefox-addons.packages."x86_64-linux"; [
        # vimium, videospeed, ublock-origin, adblocker-ultimate, and firefox-color
        # are all managed via policies.ExtensionSettings for auto-enabling
      ];
    };
  };
in
{
  stylix.targets.firefox = {
    profileNames = [ "default" "youtube" "work" "ttrpg" ];
    colorTheme.enable = true;
  };

  # Desktop files for Firefox profiles
  xdg.desktopEntries = {
    firefox-youtube = {
      name = "Firefox YouTube";
      comment = "Browse YouTube videos";
      exec = "firefox -P youtube --new-instance";
      icon = "firefox";
      categories = [ "Network" "WebBrowser" ];
    };

    firefox-work = {
      name = "Firefox Work";
      comment = "Work-related browsing";
      exec = "firefox -P work --new-instance";
      icon = "firefox";
      categories = [ "Network" "WebBrowser" "Office" ];
    };

    firefox-ttrpg = {
      name = "Firefox TTRPG";
      comment = "Tabletop RPG resources";
      exec = "firefox -P ttrpg --new-instance";
      icon = "firefox";
      categories = [ "Network" "WebBrowser" "Game" ];
    };

    firefox-default = {
      name = "Firefox Default";
      comment = "Default Firefox profile";
      exec = "firefox -P default --new-instance";
      icon = "firefox";
      categories = [ "Network" "WebBrowser" ];
    };
  };

  programs.firefox =
    {
      enable = true;
      policies = {
        ExtensionSettings = {
          "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
            installation_mode = "force_installed";
          };
          "{7be2ba16-0f1e-4d93-9ebc-5164397477a9}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/videospeed/latest.xpi";
            installation_mode = "force_installed";
          };
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };
          "adblockultimate@adblockultimate.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/adblocker-ultimate/latest.xpi";
            installation_mode = "force_installed";
          };
          "FirefoxColor@mozilla.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/firefox-color/latest.xpi";
            installation_mode = "force_installed";
          };
        };
      };
      profiles = {
        default = common // {
          name = "default";
          id = 0;
          isDefault = true;
        };
        youtube = common // {
          name = "youtube";
          id = 1;
        };
        work = common // {
          name = "work";
          id = 2;
        };
        ttrpg = common // {
          name = "ttrpg";
          id = 3;
        };
      };
    };
}
