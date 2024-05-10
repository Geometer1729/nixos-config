{inputs,pkgs,...}:
{
programs.firefox =
    {
      enable = true;
      profiles.default = {
        name = "default";
        id = 0;
        isDefault = true;
        search = {
          default = "DuckDuckGo";
          order = [ "DuckDuckGo" ];
          force = true;
          engines = {
            "Hoogle" = {
              urls = [
                { template = "https://hoogle.haskell.org/";
                  params = [{ name = "hoogle"; value = "{searchTerms}"; }];
                }];
              iconUpdateURL = "https://hoogle.haskell.org/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@h" ];
            };
            "Nix Packages" = {
              urls = [
                { template = "https://search.nixos.org/packages";
                  params = [{ name = "type"; value = "packages"; }
                            { name = "query"; value = "{searchTerms}"; }
                            { name = "channel"; value = "unstable"; }
                  ];
                }];
              icon =
                "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            "Nix Options" = {
              urls = [
                { template = "https://search.nixos.org/options";
                  params = [{ name = "type"; value = "options"; }
                            { name = "query"; value = "{searchTerms}"; }
                            { name = "channel"; value = "unstable"; }
                  ];
                }];
              icon =
                "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@no" ];
            };
            "NixOS Wiki" = {
              urls =
                [{ template = "https://nixos.wiki/index.php";
                   params = [  { name = "search"; value = "{searchTerms}"; } ];
                }];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@nw" ];
            };
            "Homemanager Options" = {
              urls =
                [{ template = "https://home-manager-options.extranix.com";
                   params = [  { name = "query"; value = "{searchTerms}"; }
                               { name = "release"; value = "master";}
                            ];
                }];
              iconUpdateURL = "https://nixos.wiki/favicon.png";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@hm" ];
            };
            "AoN" = {
              urls =
                [{ template = "https://2e.aonprd.com/Search.aspx";
                   params = [  { name = "q"; value = "{searchTerms}"; } ];
                }
                ];
              iconUpdateURL = "https://2e.aonprd.com/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@an" ];
            };
            "Minecraft wiki" = {
              urls =
                [{ template = "https://minecraft.wiki/w/Special:Search";
                   params = [  { name = "search"; value = "{searchTerms}"; } ];
                }];
              iconUpdateURL = "https://minecraft.wiki/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@mcw" ];
            };
            "SMBC" = {
              urls =
                [{ template = "https://www.ohnorobot.com/index.php";
                   params = [  { name = "s"; value = "{searchTerms}"; }
                               { name = "comic"; value = "137"; }
                               { name = "Search"; value = "Search"; }
                            ];
                }];
              iconUpdateURL = "https://www.smbc-comics.com/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = [ "@smbc" ];
            };
            "Google".metaData.hidden = true;
            "Bing".metaData.hidden = true;
            "eBay".metaData.hidden = true;
            "Amazon.com".metaData.hidden = true;
          };
        };
        settings = {
          "accessibility.typeaheadfind.enablesound"=false;
          "browser.compactmode.show" = true;
          "browser.theme.content-theme" = 0;
          "browser.theme.toolbar-theme" = 0;
          "browser.startup.page" = 1;
          "extensions.activeThemeID"="firefox-compact-dark@mozilla.org";
          "browser.newtabpage.activity-stream.feeds.section.topstories"= false;
          "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
          "browser.newtabpage.activity-stream.feeds.topsites" = false;
          "toolkit.telemetry.pioneer-new-studies-available" = false;
        };
        extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
          vimium
        ];
      };
    };
}
