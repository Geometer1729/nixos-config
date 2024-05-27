{ pkgs, userName, ... }:
let
  # The wifi driver seems to crash every ~5 minutes
  # but it will often take several hours for the first crash
  # and slowly increase frequency so restarting the
  # service periodicly when the logs indicate
  # a recent crash seems to help a lot
  wifi_fix = pkgs.writeShellApplication
    {
      name = "wifi_fix";
      text =
        ''
          if journalctl -rb | grep wpa_supplicant | \
           { head -n 1; cat > /dev/null; } | grep BEACON-LOSS \
            || (( $# >= 1 ))
          then
            sudo systemctl restart wpa_supplicant.service
            sudo systemctl restart dhcpcd.service
          fi
        '';
    };
in
{
  # using a slightly older linux kernel
  # which seems to considerably help with wifi driver issue
  # https://github.com/morrownr/7612u/issues/19
  boot.kernelPackages = pkgs.linuxPackagesFor
    (pkgs.linux_6_1.override {
      argsOverride = rec {
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          sha256 = "sha256-rSydEvw24t3keWo+7I9N3KLieAmPTlVbbm9fA+9pZM4=";
        };
        version = "6.1.61";
        modDirVersion = version;
      };
    });
  users.users.${userName}.packages = [ wifi_fix ];
  services.cron.systemCronJobs = [ "*/10 * * * * ${wifi_fix}/bin/wifi_fix" ];
}
