# Script groups

Keep `.sh` files beside their owning module and declare a named group:

```nix
scripts.cliphist = {
  directory = ./.;
  extras = with pkgs; [ cliphist wl-clipboard ];
};
```

All top-level regular `.sh` files are discovered automatically and packaged with
`writeShellApplication`, including its Bash and ShellCheck checks. Non-shell
files and subdirectories are ignored. Adding a script requires no Nix entry
unless it needs an override.

Every script gets a standard runtime toolbox: coreutils, curl, diffutils,
findutils, gawk, git, gnugrep, gnused, jq, openssh, procps, systemd, and util-linux.
GUI machines (`machine.hasGui`) also get libnotify for `notify-send`. A helper
that requires notifications on headless machines can include libnotify in its
extras. Group `extras` supply application-specific dependencies.

The same declaration works in Home Manager and NixOS. The base NixOS
configuration imports `modules/nixos/scripts` once; it registers `home.nix` for
every Home Manager user through `home-manager.sharedModules`. Feature modules
just declare their groups, with no script-support imports. Enabled scripts are
installed into `home.packages` or `environment.systemPackages`, respectively.
Each level has its own `config.scripts` registry.

## Referencing and customizing commands

Packages are exposed as `config.scripts.<group>.packages.<command>`, for example:

```nix
services.cliphist.package = config.scripts.cliphist.packages.cliphist;

scripts.cliphist.overrides.clipboard-history.extras = [
  config.scripts.cliphist.packages.cliphist
];
```

PATH priority is per-command extras, then group extras, then the standard
toolbox, with duplicate packages removed. A consumer can use a wrapper while the
wrapper itself uses the upstream executable. Avoid adding a group's own packages
to its shared extras, which would create a dependency cycle.

Groups support `enable`, `directory`, `extras`, `runtimeEnv`,
`extraShellCheckFlags`, and `overrides`. Overrides support `enable`, `source`,
`extras`, `runtimeEnv`, and `extraShellCheckFlags`. Per-command environment values
override group values; flags are appended. Normal module merging applies to
declarations of each option.

`enable = false` disables installation for a whole group or one command. Packages
remain available for service-only use and dependencies. An override's `source`
can refer to another file; an override with a new name adds a command.

## Sourced libraries and shared definitions

Put sourced helpers in a local `lib/` directory so they are not installed as
commands. It is detected automatically: the wrapper sets `SCRIPTS_LIB` to its
store path, and ShellCheck follows sources from that directory. Scripts can use:

```bash
source "$SCRIPTS_LIB/helper.sh"
```

A definition module can declare a group and be imported at both levels, as in
`modules/nixos/password/scripts.nix`. Script support is already provided by the
base configuration.
