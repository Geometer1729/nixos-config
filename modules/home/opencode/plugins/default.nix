{ lib, pkgs }:
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

  pluginFiles = builtins.filter
    (path:
      (lib.hasSuffix ".ts" path || lib.hasSuffix ".tsx" path)
      && !lib.hasSuffix ".test.ts" path)
    (filesIn ./.);

  plugins = pkgs.buildNpmPackage {
    pname = "opencode-plugins";
    version = "0";
    src = ./.;

    npmDeps = pkgs.importNpmLock { npmRoot = ./.; };
    npmConfigHook = pkgs.importNpmLock.npmConfigHook;
    npmFlags = [ "--ignore-scripts" ];
    npmInstallFlags = [ "--ignore-scripts" "--omit=dev" ];
    dontNpmBuild = true;

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
        '') pluginFiles}
      runHook postInstall
    '';
  };
in
builtins.listToAttrs (map
  (source: {
    name = "opencode/plugins/${lib.removePrefix "${toString ./.}/" (toString source)}";
    value.source = "${plugins}/${lib.removePrefix "${toString ./.}/" (toString source)}";
  })
  pluginFiles)
