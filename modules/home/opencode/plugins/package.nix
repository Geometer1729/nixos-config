# npmPlugins: plugin directory -> unpacked npm tarball of a published TypeScript
# plugin. It is copied beside the local plugins and resolves its dependencies
# from their node_modules, so it runs against the same plugin API version.
{ lib, pkgs, npmPlugins ? { } }:
let

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
  # Entry files of npmPlugins, relative to the package, for the load check:
  # the "." export is a server plugin, "./tui" a TUI one.
  npmEntrypoints = lib.concatLists (lib.mapAttrsToList
    (name: source:
      let
        metadata = builtins.fromJSON (builtins.readFile "${source}/package.json");
        entry = target: "${name}/${lib.removePrefix "./" (target.import or target)}";
      in
      lib.optional (metadata.exports ? ".") { path = entry metadata.exports."."; server = true; }
      ++ lib.optional (metadata.exports ? "./tui") { path = entry metadata.exports."./tui"; server = false; })
    npmPlugins);

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
        cp -r ${source} "$out/${name}"
        chmod -R u+w "$out/${name}"
      '') npmPlugins)}
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
