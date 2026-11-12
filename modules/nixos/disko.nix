{ config, pkgs, ... }:
let
  device = config.drive;
  inherit (pkgs) lib;
in
{
  options.drive = lib.mkOption
    {
      type = lib.types.str;
      description = "the drive to mount with disko.nix";
    };
  config = {
    disko.devices = {
      disk.main = {
        inherit device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "4G";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "root_vg";
              };
            };
          };
        };
      };
      lvm_vg = {
        root_vg = {
          type = "lvm_vg";
          lvs = {
            root = {
              size = "100%FREE";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];

                # btrfs applies compress to the whole filesystem from whichever
                # subvolume mounts first, so every subvolume carries it.
                subvolumes = {
                  "/root" = {
                    mountOptions = [ "compress=zstd:1" ];
                    mountpoint = "/";
                  };

                  "/persist" = {
                    mountOptions = [ "subvol=persist" "noatime" "compress=zstd:1" ];
                    mountpoint = "/persist";
                  };

                  "/nix" = {
                    mountOptions = [ "subvol=nix" "noatime" "compress=zstd:1" ];
                    mountpoint = "/nix";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
