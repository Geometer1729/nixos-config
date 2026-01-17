{ ... }:
final: prev:
{
  # Replace taskwarrior2 globally with taskwarrior3
  taskwarrior2 = final.taskwarrior3;

  # Override python3Packages.tasklib to use taskwarrior3
  python3Packages = prev.python3Packages.override {
    overrides = pythonSelf: pythonSuper: {
      tasklib = pythonSuper.tasklib.override {
        taskwarrior2 = final.taskwarrior3;
      };
    };
  };

  # Override vit to use taskwarrior3 and add case-insensitive search
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
