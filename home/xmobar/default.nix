{ opts, ... }:
let
  when = cond: val: if cond then val else "";
in
{
  programs.xmobar =
    {
      enable = true;
      extraConfig =
        ''
                Config
                 { font = "xft:Fira Mono"
                 , additionalFonts = []
                 , borderColor = "black"
                 , border = TopB
                 , bgColor = "black"
                 , fgColor = "#f3f4f5"
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
                 , template = " %cpu% | %memory% | %multicoretemp% | %UnsafeStdinReader% }\
                           \{ ${when opts.wifi.enable (" %" + opts.wifi.interface + "wi% |")} ${ when opts.battery " %battery% |"}%alsa:default:Master%| %date% "
                 , commands =
                    [ Run UnsafeStdinReader
                    , Run Cpu ["-L","5","-H","70",
                               "--normal","green","--high","red"] 10
                    , Run Memory ["-t","Mem: <usedratio>%"] 10
                    , Run Date "%m-%d-%y : %a : %H:%M:%S" "date" 10
                    , Run CatInt 0 "/sys/class/backlight/intel_backlight/brightness" [] 50
                    , Run MultiCoreTemp ["-t", "Temp: <avg>°C (<avgpc>%)",
                       "-L", "60", "-H", "80",
                       "-l", "green", "-n", "yellow", "-h", "red",
                       "--", "--mintemp", "20", "--maxtemp", "100"] 50
                    , Run Battery        [ "--template" , "Batt: <acstatus>"
                            , "--Low"      , "10"
                            , "--High"     , "80"
                            , "--low"      , "darkred"
                            , "--normal"   , "darkorange"
                            , "--high"     , "darkgreen"
                            , "--" -- battery specific options
                                      -- discharging status
                                      , "-o"	, "<left>% (<timeleft>)"
                                      -- AC "on" status
                                      , "-O"	, "<fc=#dAA520>Charging</fc> (<left>%)"
                                      -- charged status
                                      , "-i"	, "<fc=#006000>Charged</fc>"
                            ] 50
                    , Run Alsa "default" "Master" ["--template", "<volume>% <status>"]
                    ${when opts.wifi.enable (", Run Wireless \"" +  opts.wifi.interface + "\" [] 10")}
                    ]
          	    }
        '';

    };

}
