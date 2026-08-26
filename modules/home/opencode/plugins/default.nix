{ lib }:
let
  filesIn = directory:
    builtins.concatMap
      (name:
        let
          path = directory + "/${name}";
          type = (builtins.readDir directory).${name};
        in
        if type == "directory" then filesIn path else lib.optional (type == "regular") path)
      (builtins.attrNames (builtins.readDir directory));

  pluginFiles = builtins.filter
    (path:
      (lib.hasSuffix ".ts" path || lib.hasSuffix ".tsx" path)
      && !lib.hasSuffix ".test.ts" path)
    (filesIn ./.);
in
builtins.listToAttrs (map
  (source: {
    name = "opencode/plugins/${lib.removePrefix "${toString ./.}/" (toString source)}";
    value = { inherit source; };
  })
  pluginFiles)
