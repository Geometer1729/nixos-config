update:
  nh os switch -u && nix develop --command "git add . && git commit -m update"
