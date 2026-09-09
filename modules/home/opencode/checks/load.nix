{ lib, pkgs, home }:
let
  plugins = import ../plugins/package.nix { inherit lib pkgs; };
  files = lib.filterAttrs (name: _: lib.hasPrefix "opencode/plugins/" name) home.xdg.configFile;
  # Find definitions independently of their filenames, so a misplaced plugin
  # fails the check instead of silently disappearing from the expected list.
  entrypoints = builtins.filter
    (source: lib.hasInfix "export default Plugin.define(" (builtins.readFile source))
    plugins.sourceFiles;
  entries = pkgs.writeText "opencode-plugin-entries.json" (builtins.toJSON (map
    (source: {
      path = lib.removePrefix "${toString ../plugins}/" (toString source);
      server = !(lib.hasInfix "plugin/tui\"" (builtins.readFile source));
    })
    entrypoints));
  opencode = lib.findFirst (package: (package.pname or "") == "opencode2")
    (throw "OpenCode plugin load check requires the deployed opencode2 package")
    home.home.packages;
in
pkgs.runCommand "opencode-plugin-load"
{
  nativeBuildInputs = [ opencode pkgs.jq pkgs.git ];
  preferLocalBuild = true;
  meta.timeout = 120;
}
  ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
    export OPENCODE_DISABLE_MODELS_FETCH=true OPENCODE_DISABLE_FILEWATCHER=true
    export OPENCODE_CHECK_ENTRIES=${entries} OPENCODE_CHECK_EXPECTED="$TMPDIR/expected.json"
    mkdir -p "$XDG_CONFIG_HOME/opencode/plugins/load-probe" "$TMPDIR/project"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: file: ''
      ln -s ${lib.escapeShellArg (toString file.source)} "$XDG_CONFIG_HOME/${name}"
    '') files)}
    cp ${./probe.js} "$XDG_CONFIG_HOME/opencode/plugins/load-probe/index.js"
    # Keep the real plugin registrations, omitting credentials and unrelated services.
    jq --arg old ${lib.escapeShellArg home.xdg.configHome} --arg new "$XDG_CONFIG_HOME" '
      {plugins, plugin} | with_entries(select(.value != null)) |
      walk(if type == "string" then split($old) | join($new) else . end) |
      .update = "disable"
    ' ${home.xdg.configFile."opencode/opencode.json".source} > "$XDG_CONFIG_HOME/opencode/opencode.json"
    cd "$TMPDIR/project"
    trap 'opencode2 service stop >/dev/null 2>&1 || true' EXIT
    opencode2 api post /api/plugin/await-activation
    opencode2 api get /api/plugin > "$TMPDIR/plugins.json"
    jq -e --slurpfile expected "$OPENCODE_CHECK_EXPECTED" '
      [.data[] | select(.source.type != "builtin")] as $plugins |
      if all($plugins[]; .state.status == "active") and
         (($expected[0] | map(select(.server) | .id)) - ($plugins | map(.id)) | length == 0)
      then $expected[0] | map(.id)
      else error("Missing or failed plugins: " + ($plugins | tojson)) end
    ' "$TMPDIR/plugins.json"
    touch "$out"
  ''
