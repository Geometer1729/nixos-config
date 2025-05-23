{ pkgs, config, ... }:
let
  inherit (pkgs) lib;
  when = cond: val: if cond then val else "";
  font = config.stylix.fonts.monospace.name;
  wifi = when config.wifi.enable (" %" + config.wifi.interface + "wi% |");
  battery = when config.battery "%battery% |";
in
with config.lib.stylix.colors.withHashtag;
{
  options.wifi.enable = lib.mkOption {
    type = lib.types.bool;
    description = "show wifi on the status bar";
    default = false;
  };
  options.wifi.interface = lib.mkOption {
    type = lib.types.str;
    description = "name of wifi interface";
  };
  options.battery = lib.mkOption {
    type = lib.types.bool;
    description = "show battery on the status bar";
    default = false;
  };
  # required for the volume display to work
  # maybe I should make a pr to add `withAlsa` as an option in home-manager
  config.home.packages = [ pkgs.alsa-utils ];
  config.programs.xmobar =
    {
      enable = true;
      extraConfig =
        ''
          Config
           { font = "${font}"
           , additionalFonts = []
           , borderColor = "${base01}"
           , border = TopB
           , bgColor = "${base00}"
           , fgColor = "${base05}"
           , alpha = 255
           , position = Bottom
           , textOffset = -1
           , iconOffset = -1
           , lowerOnStart = True
           , pickBroadest = False
           , persistent = False
           , hideOnStart = False
           , iconRoot = "."
           , allDesktops = True
           , overrideRedirect = True
           , sepChar = "%"
           , alignSep = "}{"
           , template = " %cpu% | %memory%:%swap% | %multicoretemp% | %UnsafeStdinReader% }\
                     \{ ${wifi} ${battery}%alsa:default:Master%| %date% "
           , commands =
              [ Run UnsafeStdinReader
              , Run Cpu ["-L","5","-H","70",
                         "--normal","${green}","--high","${red}"] 10
              , Run Memory ["-t","Mem: <usedratio>%"] 10
              , Run Swap ["-t","<usedratio>%"] 10
              , Run Date "%m-%d-%y : %a : %H:%M:%S" "date" 10
              , Run CatInt 0 "/sys/class/backlight/intel_backlight/brightness" [] 50
              , Run MultiCoreTemp ["-t", "Temp: <avg>°C (<avgpc>%)",
                 "-L", "60", "-H", "80",
                 "-l", "${green}", "-n", "${yellow}", "-h", "${red}",
                 "--", "--mintemp", "20", "--maxtemp", "100"] 50
              , Run Battery        [ "--template" , "Batt: <acstatus>"
                      , "--Low"      , "10"
                      , "--High"     , "80"
                      , "--low"      , "${red}"
                      , "--normal"   , "${orange}"
                      , "--high"     , "${green}"
                      , "--" -- battery specific options
                                -- discharging status
                                , "-o"	, "<left>% (<timeleft>)"
                                -- AC "on" status
                                , "-O"	, "<fc=${green}>Charging</fc> (<left>%)"
                                -- charged status
                                , "-i"	, "<fc=${yellow}>Charged</fc>"
                      ] 50
              , Run Alsa "default" "Master"
                [ "--template", "<volume>% <status>", "--"
                ,"--offc","${red}"
                ,"--onc","${green}"
                ]
              ${when config.wifi.enable (", Run Wireless \"" +  config.wifi.interface + "\" [] 10")}
              ]
          }
        '';

    };

}
