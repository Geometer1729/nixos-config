# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository managed using flakes and nixos-unified. It contains system and home-manager configurations for multiple machines, with a modular structure separating concerns between NixOS system configuration and home-manager user configuration.

## Common Commands

### System Operations
- `just update` - Update the system configuration and commit changes
- `nh os switch` - Switch to the current configuration
- `nh os test` - Test the configuration without switching (used by rebuild scripts)
- `nixpkgs-fmt` - Format Nix files using nixpkgs-fmt

### Development
- `nix develop` - Enter the development shell
- `nixd` - Nix language server (available in development environment)
- `nixpkgs-fmt` - Format Nix files

### Testing and Debugging
- Rebuild scripts are located in `modules/home/scripts/` and use `nh os test` with output redirection to `~/Downloads/nixerr`
- Test configurations before applying with `nh os test`

## Architecture

### Directory Structure
- `configurations/` - Host-specific configurations
  - `home/` - Home-manager configurations (bbrian.nix, root.nix)
  - `nixos/` - NixOS system configurations by hostname (am/, torag/)
- `modules/` - Reusable configuration modules
  - `flake-parts/` - Flake-parts modules (devshell, neovim, toplevel, xmonad)
  - `home/` - Home-manager modules (applications, development tools, scripts)
  - `nixos/` - NixOS system modules (boot, networking, security, etc.)

### Key Files
- `flake.nix` - Main flake configuration with inputs and outputs

### Configuration Pattern
The repository uses nixos-unified for configuration management with:
- Auto-wiring of configurations based on directory structure
- Separation of system (NixOS) and user (home-manager) configurations
- Modular approach with reusable modules in `modules/`
- Host-specific configurations in `configurations/`

### Machine Configurations
- `am` - Primary desktop with AMD GPU, dual monitor setup (HDMI-1 primary 2560x1440, DP-2 secondary 1920x1080)
- `torag` - Secondary machine configuration

### Development Environment
- Haskell development setup with GHC 9.8.2 and XMonad
- Neovim configuration with Nixvim
- Custom scripts for system rebuilding and tmux integration

### Window Manager
- XMonad window manager with custom configuration in `modules/home/xmonad/`
- XMobar status bar configuration
- Sway as alternative window manager

The configuration emphasizes reproducibility, modularity, and integration between system and user environments through the Nix ecosystem.
