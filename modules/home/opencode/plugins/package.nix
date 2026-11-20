# npmPlugins: plugin directory -> registry metadata of a published TypeScript
# plugin. It is unpacked beside the local plugins and resolves its dependencies
# from their node_modules, so it runs against the same plugin API version.
{ lib, pkgs, npmPlugins ? { } }:
let
  npmSources = lib.mapAttrs
    (_: metadata: pkgs.fetchurl {
      url = metadata.dist.tarball;
      hash = metadata.dist.integrity;
    })
    npmPlugins;

  filesIn = directory:
    builtins.concatMap
      (name:
        let
          path = directory + "/${name}";
          type = (builtins.readDir directory).${name};
        in
        if name == "node_modules" then [ ]
        else if type == "directory" then filesIn path
        else lib.optional (type == "regular") path)
      (builtins.attrNames (builtins.readDir directory));

  sourceFiles = builtins.filter
    (path:
      (lib.hasSuffix ".ts" path || lib.hasSuffix ".tsx" path)
      && !lib.hasSuffix ".test.ts" path)
    (filesIn ./.);

  common = {
    version = "0";
    src = ./.;

    npmDeps = pkgs.importNpmLock { npmRoot = ./.; };
    npmConfigHook = pkgs.importNpmLock.npmConfigHook;
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;
  };
in
{
  inherit sourceFiles;
  # Entry files of npmPlugins, relative to the package, for the load check.
  npmEntrypoints = lib.mapAttrsToList
    (name: metadata: "${name}/${lib.removePrefix "./" (metadata.exports.".".import or metadata.exports.".")}")
    npmPlugins;

  check = pkgs.buildNpmPackage (common // {
    pname = "opencode-plugins-check";

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      npm run typecheck
      npm test
      runHook postCheck
    '';

    installPhase = ''
      mkdir -p "$out"
    '';
  });

  package = pkgs.buildNpmPackage (common // {
    pname = "opencode-plugins";

    npmInstallFlags = [ "--ignore-scripts" "--omit=dev" ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp package.json tsconfig.json "$out/"
      cp -r node_modules "$out/"
      ${lib.concatMapStringsSep "\n" (source:
        let
          relative = lib.removePrefix "${toString ./.}/" (toString source);
        in
        ''
          mkdir -p "$out/$(dirname '${relative}')"
          cp '${relative}' "$out/${relative}"
        '') sourceFiles}
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: source: ''
        mkdir "$out/${name}"
        tar -xzf ${source} -C "$out/${name}" --strip-components=1
      '') npmSources)}
      # Keep dependency lookup valid through Home Manager's directory symlinks,
      # including when OpenCode hot-loads a plugin using its config-directory path.
      for plugin in "$out"/*/; do
        if [ "$(basename "$plugin")" != node_modules ]; then
          ln -s ../node_modules "$plugin/node_modules"
        fi
      done
      runHook postInstall
    '';
  });
}
