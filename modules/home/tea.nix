{ pkgs, ... }:
let
  url = "https://git.urlmoles.com";
  tokenFile = "/run/secrets/gitea";
  tea = pkgs.symlinkJoin {
    name = "tea-${pkgs.tea.version}";
    paths = [ pkgs.tea ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/tea \
        --set-default GITEA_INSTANCE_URL ${url} \
        --set-default GITEA_INSTANCE_SSH_HOST whitehouse \
        --run 'if [ -z "''${GITEA_TOKEN:-}" ] && [ -r ${tokenFile} ]; then export GITEA_TOKEN="$(< ${tokenFile})"; fi'
    '';
  };
in
{
  home.packages = [ tea ];

  # The empty helper drops the global store helper so the token is never written to disk.
  programs.git.settings.credential.${url}.helper = [
    ""
    "!f() { [ \"$1\" = get ] || exit 0; printf 'username=bbrian\\npassword=%s\\n' \"$(cat ${tokenFile})\"; }; f"
  ];
}
