{lib,pkgs,...}:
let
recursiveMerge = with lib; attrList:
  let f = attrPath:
    lib.zipAttrsWith (n: values:
      if tail values == []
        then head values
      else if all isList values
        then unique (concatLists values)
      else if all isAttrs values
        then f (attrPath ++ [n]) values
      else last values
    );
  in f [] attrList;
importYaml = file: builtins.fromJSON
  (builtins.readFile
    (pkgs.runCommandNoCC "converted-yaml.json" {}
     ''${pkgs.yj}/bin/yj < "${file}" > "$out"''
    ));
in
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "met"
      "rest"
      "calendar"
      "local_calendar"
      "time_date"
      "radio_browser"
    ];
    customLovelaceModules =
      [ (import ./stack-in-card.nix {inherit lib pkgs;})
        pkgs.home-assistant-custom-lovelace-modules.mini-media-player
      ];
    extraPackages = python3Packages: with python3Packages; [
      gtts
    ];
    openFirewall = true;
    configWritable = true;
    #lovelaceConfig = importYaml ./lovelace.yml;
    config = recursiveMerge [
      (importYaml ./extra.yml)
      { #lovelace.mode = "yaml";
      }
      (import ./mk-hm.nix
        {
        #real vesta
        vesta_addr = "http://192.168.1.41:8080";
        #bbb
        #vesta_addr = "http://192.168.1.131:8080";
         readable =
           [ "Basement_Temp"
             "Main_Floor_Temp"
             "Master_BR_Temp"
             "Guest_Room_Temp"
             "Tank_kbtu"
             "Combustion_Temp"
             "Buzzer"
             "Flue_Hot"
             #"hm_test_var"
           ];
         setable = [
           { name = "Top_Floor_Nominal";
             min = 55;
             max = 80;
             step = 1;
           }
           { name = "Main_Floor_Nominal";
             min = 55;
             max = 80;
             step = 1;
           }
           { name = "Basement_Nominal";
             min = 55;
             max = 80;
             step = 1;
           }
         ];
         inherit lib;
        })
      ];
  };

}
