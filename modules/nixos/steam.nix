{ config, pkgs, ... }:
{


  users.users.${config.mainUser} = {
    packages = with pkgs; [
      steam
      steam-run
      libgdiplus
      glxinfo
    ];
  };

  services.pulseaudio.support32Bit = true;
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  } // (if config.amd then
    {
      amdgpu.amdvlk = {
        enable = true;
        support32Bit.enable = true;
      };
    } else { });

  security.pam.loginLimits = [
    { domain = "*"; item = "nofile"; type = "-"; value = 16777216; }
  ];
  programs.nix-ld.enable = true;
  # TODO figure out how much of this is actually needed
  programs.nix-ld.libraries = with pkgs; [
    # Add any missing dynamic libraries for unpackaged programs

    # here, NOT in environment.systemPackages
    # common requirement for several games
    stdenv.cc.cc.lib

    # from https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/games/steam/fhsenv.nix#L72-L79
    xorg.libXcomposite
    xorg.libXtst
    xorg.libXrandr
    xorg.libXext
    xorg.libX11
    xorg.libXfixes
    libGL
    libva

    # from https://github.com/NixOS/nixpkgs/blob/nixos-23.05/pkgs/games/steam/fhsenv.nix#L124-L136
    fontconfig
    freetype
    xorg.libXt
    xorg.libXmu
    libogg
    libvorbis
    SDL
    SDL2_image
    glew110
    libdrm
    libidn
    tbb

  ];
}
