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
      runHook postInstall
    '';
  });
}
