{ flake, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

  networking.hostName = "am";
  machine.hasGui = true;
  networking.interfaces.enp4s0.wakeOnLan.enable = true;
  amd = true;
  drive = "/dev/nvme0n1";
  system.stateVersion = "25.05";

  # Cross-compilation support via QEMU binfmt emulation
  nix.settings.extra-platforms = [ "i686-linux" "aarch64-linux" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.pipewire.wireplumber = {
    extraScripts."default-nodes/prefer-blue-snowball.lua" = ''
      SimpleEventHook {
        name = "default-nodes/prefer-blue-snowball",
        after = {
          "default-nodes/find-best-default-node",
          "default-nodes/find-selected-default-node",
          "default-nodes/find-stored-default-node",
        },
        before = { "default-nodes/apply-default-node" },
        interests = {
          EventInterest {
            Constraint { "event.type", "=", "select-default-node" },
            Constraint { "default-node.type", "=", "audio.source" },
          },
        },
        execute = function (event)
          local available_nodes = event:get_data ("available-nodes")
          available_nodes = available_nodes and available_nodes:parse ()
          if not available_nodes then
            return
          end

          for _, node_props in ipairs (available_nodes) do
            local name = node_props ["node.name"]
            if name and name:match ("^alsa_input%.usb%-BLUE_MICROPHONE_Blue_Snowball_") then
              event:set_data ("selected-node-priority", 100000)
              event:set_data ("selected-node", name)
              return
            end
          end
        end,
      }:register ()
    '';

    extraConfig."99-prefer-blue-snowball" = {
      "wireplumber.components" = [
        {
          name = "default-nodes/prefer-blue-snowball.lua";
          type = "script/lua";
          provides = "custom.prefer-blue-snowball";
        }
      ];
      "wireplumber.profiles".main."custom.prefer-blue-snowball" = "required";
    };
  };

  # Monitor setup for desktop
  home-manager.users.bbrian = {
    # Disable hypridle completely on this machine to test if it's causing display flickering
    services.hypridle.enable = lib.mkForce false;

    programs.hyprland-custom = {
      dualMonitor = true;
      primaryMonitor = "HDMI-A-1,2560x1440@60,0x0,1";
      secondaryMonitor = "DP-1,1920x1080@60,2560x0,1";
    };
  };

  imports = [
    ./hardware.nix
  ] ++ (with self.nixosModules; [
    default
    builder
    foundryvtt
  ]);
}
