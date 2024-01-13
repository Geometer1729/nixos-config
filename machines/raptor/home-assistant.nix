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
  # openssl-1.1 is in EOL but
  # ha still needs it
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];
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
             "Flue_Temp"
             "Zone_Return_Temp"
             "Wood_Out_Temp"
             "Wood_In_Temp"
             "DHW"
             "Tank_Circ"
             "Wood_Boiler_Recirc"
             "Wood_Recirc_Enabled"
             "DHW_Zone_Valve"
             "Tank_Zone_Valve"
             "Preheat_Timer"
             "Phase_I_Timer"
             "Phase_II_Timer"
             "Phase_III_Timer"
             "Burn_Out_Timer"
             "Combustion_Warm"
             "Fire_Near_Target"
             "Flue_Warm"
             "Wood_Boiler_Active"
             "Wood_Boiler_Warm"
             "Wood_Boiler_Hot"
             "Wood_Boiler_Too_Hot"
             "Wood_Boiler_Scavenge"
             "Cool_Return"
             "Top_Floor_ZV"
             "Main_Floor_ZV"
             "Basement_ZV"
             "Tank_Bottom_Temp"
             "Tank_Middle_Temp"
             "Tank_Top_Temp"
             "Zone_Inhibit"
             "Wood_Boiler_Circ"
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
           { name = "Wood_Boiler_Fan";
             min = 0;
             max = 100;
             step = 1;
           }
           { name = "Fossil_Setback";
             min = 0;
             max = 20;
             step = 1;
           }
         ];
         inherit lib;
        })
      ];
  };

}
