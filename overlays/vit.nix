_:
final: prev:
{
  # Route taskwarrior2 package arguments to taskwarrior3 for this task setup.
  # Remove these remaps once nixpkgs wires VIT/tasklib to taskwarrior3.
  taskwarrior2 = final.taskwarrior3;

  # tasklib still expects taskwarrior2 in nixpkgs.
  python3Packages = prev.python3Packages.override {
    overrides = _pythonSelf: pythonSuper: {
      tasklib = pythonSuper.tasklib.override {
        taskwarrior2 = final.taskwarrior3;
      };
    };
  };

  # nixpkgs' VIT package still takes taskwarrior2, and upstream search remains
  # case-sensitive. Remove the patch once upstream or nixpkgs grows an
  # equivalent case-insensitive search behavior.
  vit = (prev.vit.override {
    taskwarrior2 = final.taskwarrior3;
  }).overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (final.writeText "vit-case-insensitive-search.patch" ''
        --- a/vit/application.py
        +++ b/vit/application.py
        @@ -538,7 +538,7 @@ class Application:

             def search_rows(self, term, start_index=0, reverse=False):
                 escaped_term = re.escape(term)
        -        search_regex = re.compile(escaped_term, re.MULTILINE)
        +        search_regex = re.compile(escaped_term, re.MULTILINE | re.IGNORECASE)
                 rows = self.table.rows
                 current_index = start_index
                 last_index = len(rows) - 1
      '')
    ];
  });
}
