{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Games
    #prismlauncher  # Temporarily disabled - OpenJDK circular dependency
  ];

}
