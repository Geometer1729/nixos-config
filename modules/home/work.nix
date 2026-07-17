{ flake, pkgs, ... }:
let
  linearisSource = flake.inputs.linearis;
  linearisPackage = builtins.fromJSON (builtins.readFile "${linearisSource}/package.json");
  linearisLock = builtins.fromJSON (builtins.readFile "${linearisSource}/package-lock.json");
  linearisNpm = builtins.fromJSON (builtins.readFile flake.inputs.linearis-npm);
  linearisRuntimePackage = builtins.removeAttrs linearisPackage [ "devDependencies" ];
  linearisRuntimePackages = pkgs.lib.filterAttrs (_: dependency: !(dependency.dev or false)) linearisLock.packages;
  linearisRuntimeLock = linearisLock // {
    packages = linearisRuntimePackages // {
      "" = builtins.removeAttrs linearisRuntimePackages."" [ "devDependencies" ];
    };
  };

  linearis =
    assert linearisPackage.version == linearisNpm.version;
    pkgs.buildNpmPackage {
      pname = "linearis";
      inherit (linearisPackage) version;
      src = pkgs.fetchurl {
        url = linearisNpm.dist.tarball;
        hash = linearisNpm.dist.integrity;
      };
      sourceRoot = "package";

      npmDeps = pkgs.importNpmLock {
        npmRoot = linearisSource;
        package = linearisRuntimePackage;
        packageLock = linearisRuntimeLock;
      };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      npmFlags = [ "--ignore-scripts" ];
      npmInstallFlags = [ "--ignore-scripts" ];
      dontNpmBuild = true; # npm publishes pre-built JavaScript.

      nodejs = pkgs.nodejs_22;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postFixup = ''
        wrapProgram $out/bin/linearis \
          --run 'if [ -z "''${LINEAR_API_TOKEN:-}" ] && [ -r /run/secrets/linear_api_key ]; then export LINEAR_API_TOKEN="$(< /run/secrets/linear_api_key)"; fi'
      '';
    };
in
{
  imports = [ flake.inputs.mighty-rearranger.homeManagerModules.default ];

  home.packages =
    with pkgs;
    [
      linearis
      slack
      google-chrome
    ];

  programs.zsh.initContent = ''
    if [ -f /run/secrets/linear_api_key ]; then
      LINEAR_API_TOKEN="$(< /run/secrets/linear_api_key)"
      export LINEAR_API_TOKEN
    fi
  '';

  programs.ssh.matchBlocks =
    let
      me = {
        identityFile = "/home/bbrian/.ssh/id_ed25519";
      };
    in
    {
      vault = me // { hostname = "vault.geosurge.ai"; user = "doma"; };
      geomancer = me // { hostname = "geomancer.geosurge.ai"; user = "operator"; };
    };
}
