{ ... }:

{
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  services.blueman = {
    enable = true;
    # Blueman now ships its own user unit; the old NixOS applet wrapper duplicates
    # ExecStart and produces an invalid user service.
    withApplet = false;
  };
}
