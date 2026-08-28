{ ... }:
let
  siteSearch = name: shortcut: url: {
    inherit name shortcut url;
    allow_user_override = true;
  };
in
{
  stylix.targets.chromium.colors.enable = false;

  environment.etc."brave/policies/managed/browser.json".text = builtins.toJSON {
    RestoreOnStartup = 1;
    PasswordManagerEnabled = false;
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "DuckDuckGo";
    DefaultSearchProviderKeyword = "duckduckgo.com";
    DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";

    SiteSearchSettings = [
      (siteSearch "Hoogle" "h" "https://hoogle.haskell.org/?hoogle={searchTerms}")
      (siteSearch "Nix Packages" "np" "https://search.nixos.org/packages?type=packages&channel=unstable&query={searchTerms}")
      (siteSearch "Nix Options" "no" "https://search.nixos.org/options?type=options&channel=unstable&query={searchTerms}")
      (siteSearch "NixOS Wiki" "nw" "https://nixos.wiki/index.php?search={searchTerms}")
      (siteSearch "Home Manager Options" "hm" "https://home-manager-options.extranix.com/?query={searchTerms}&release=master")
      (siteSearch "Archives of Nethys" "an" "https://2e.aonprd.com/Search.aspx?q={searchTerms}")
      (siteSearch "Minecraft Wiki" "mcw" "https://minecraft.wiki/w/Special:Search?search={searchTerms}")
      (siteSearch "SMBC" "smbc" "https://www.ohnorobot.com/index.php?s={searchTerms}&comic=137&Search=Search")
    ];
  };
}
