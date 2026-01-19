# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Meta Instructions

When the user provides design guidance or asks for changes based on design principles, architectural decisions, or organizational preferences, you should:
1. Implement the requested changes
2. Update this CLAUDE.md file to incorporate that understanding for future interactions
3. Add the new guidance to the appropriate section to ensure consistency in future decisions

This ensures that design decisions and architectural preferences are captured and applied consistently across all interactions.

## Repository Overview

This is a NixOS configuration repository managed using flakes and nixos-unified. It contains system and home-manager configurations for multiple machines, with a modular structure separating concerns between NixOS system configuration and home-manager user configuration.

## Common Commands

### System Operations
- `just` - The justfile contains some handy commands
- `nix develop` - Enter the development shell
- `nh os test` - Test the configuration

## Testing Changes

**CRITICAL**: Always verify changes work before considering them complete. Never tell the user you're done without running the build check first.

0. **Git tracking**: If you created ANY new files (especially `.nix` files), run `git add <file>` IMMEDIATELY - Nix flakes can only see git-tracked files. This is MANDATORY before any build attempt. Do not git add files which are only modified.
1. **Test changes**: Run `nh os test` to switch to the configuration (doesn't set as default boot).
2. **Verify functionality**: Test that your changes work as expected or outline what should be tested manually

Don't mark work as complete if the configuration doesn't build or if functionality is broken.

## Impermanence

This system uses impermanence - the root filesystem is wiped on reboot and only explicitly persisted paths survive via bind mounts from `/persist/system/`.

When changing what's persisted in `modules/nixos/impermanence.nix`:
- Activating the new config creates bind mounts that **hide** (not erase) existing data
- If data appears "lost" after activation, unmount the bind mount to access the hidden data: `sudo umount ~/.some-path`
- Copy the hidden data to the persist location, then remount

Data on the ephemeral root is only truly lost on reboot.

## Architecture

### Directory Structure
- `configurations/` - Host-specific configurations
  - `home/` - Home-manager configurations (bbrian.nix, root.nix)
  - `nixos/` - NixOS system configurations by hostname (am/, torag/)
- `modules/` - Reusable configuration modules
  - `flake-parts/` - Flake-parts modules (devshell, neovim, toplevel)
  - `home/` - Home-manager modules (applications, development tools, scripts)
  - `nixos/` - NixOS system modules (boot, networking, security, etc.)

### Key Files
- `flake.nix` - Main flake configuration with inputs and outputs
- `modules/home/hyprland/hyprland.nix` - Hyprland window manager configuration
- `modules/home/hyprland/waybar.nix` - Waybar status bar configuration
- `modules/home/nvim/nixvim.nix` - Main neovim configuration

### Configuration Pattern
The repository uses nixos-unified for configuration management with:
- Auto-wiring of configurations based on directory structure
- Separation of system (NixOS) and user (home-manager) configurations
- Modular approach with reusable modules in `modules/`
- Host-specific configurations in `configurations/`

#### Modular Design Guidelines
- **Modules should be general and reusable**: Code in `modules/` should not contain hostname conditionals or machine-specific logic
- **Machine-specific configuration belongs in `configurations/`**: Any configuration that depends on the hostname or is specific to a machine should be placed in `configurations/nixos/[hostname]/` or `configurations/home/[username].nix`
- **No hostname conditionals in modules**: Avoid `if config.networking.hostName == "..."` patterns in modules as they break modularity and reusability
- **Composition over conditionals**: Let machine configurations compose and override module defaults rather than embedding conditionals in shared modules

This ensures modules remain clean, testable, and reusable across different machines while keeping machine-specific details properly isolated.

#### Configuration Placement Guidelines
When adding configurations, consider the functional purpose rather than just the setting type:
- **Application-specific settings** (including cron jobs, systemd services) should be placed in the relevant application module (e.g., nvim-related cron jobs go in `modules/home/nvim/`)
- **General system settings** should be placed in appropriate system modules
- **Scripts and utilities** should be in `modules/home/scripts/` regardless of their trigger mechanism

### Machine Configurations
- `am` - Primary desktop with AMD GPU, dual monitor setup (HDMI-1 primary 2560x1440, DP-2 secondary 1920x1080)
- `torag` - Secondary machine configuration

### Development Environment
- Haskell development setup with GHC
- Neovim configuration with Nixvim
- Custom scripts for system rebuilding and tmux integration

### Window Manager
- Hyprland - Wayland compositor with custom configuration in `modules/home/hyprland/`
  - Waybar - Status bar (replaces Xmobar)
  - Hyprlock - Screen locker
  - Hypridle - Idle management
  - Hyprpaper - Wallpaper manager
  - Rofi - Application launcher (Wayland-compatible)

The configuration emphasizes reproducibility, modularity, and integration between system and user environments through the Nix ecosystem.
