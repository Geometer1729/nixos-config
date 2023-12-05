{ lib
, pkgs
}:

pkgs.buildNpmPackage rec {
  pname = "stack-in-card";
  version = "0.2.0";

  src = pkgs.fetchFromGitHub {
    owner = "custom-cards";
    repo = "stack-in-card";
    rev = "refs/tags/${version}";
    hash = "sha256-EVv1C6AcrYeMS5lYDRodkl3CTRpbg3szi1uhDc3boZ4=";
  };

  patches = [ ./0001-add-package-lock.patch ];


  npmDepsHash = "sha256-EP0hIaNDQkTtuGfdTPtmU6vjt+oXC+YglyZ33EDmgUo=";

  npmFlags = [ "--legacy-peer-deps" ];
  makeCacheWritable = true;

  installPhase = ''
    runHook preInstall

    mkdir $out
    cp -v dist/stack-in-card.js $out/

    runHook postInstall
  '';

  passthru.entrypoint = "stack-in-card.js";

  meta = with lib; {
    changelog = "https://github.com/custom-cards/stack-in-card/releases/tag/${version}";
    description = "group multiple cards into one card without the borders";
    homepage = "https://github.com/custom-cards/stack-in-card/";
    maintainers = with maintainers; [ hexa ];
    license = licenses.mit;
  };
}
