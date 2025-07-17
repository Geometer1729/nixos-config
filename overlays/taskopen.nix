{ ... }:
final: prev: {
  # Taskopen was rewritten in nim
  # so it's easier to start from scratch than overrideAttrs
  # I should really update it in nixpkgs
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
