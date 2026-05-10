{ ... }:
final: prev: {
  # Keep taskopen on the 2.x Nim rewrite because nixpkgs still packages the
  # older 1.1.5 Perl implementation. Remove this overlay once nixpkgs updates
  # taskopen to a 2.x release that still works with this task workflow.
  taskopen = final.stdenv.mkDerivation {
    pname = "taskopen-nim";
    version = "2.0.1";

    src = prev.fetchFromGitHub {
      owner = "ValiValpas";
      repo = "taskopen";
      rev = "v2.0.1";
      sha256 = "sha256-Gy0QS+FCpg5NGSctVspw+tNiBnBufw28PLqKxnaEV7I=";
    };

    buildInputs = [ prev.nim ];
    nativeBuildInputs = [ prev.nim ];

    buildPhase = ''
      runHook preBuild
      nim c -d:release --nimcache:$TMPDIR src/taskopen.nim
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp src/taskopen $out/bin/
      runHook postInstall
    '';
  };

}
