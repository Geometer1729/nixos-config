update:
  nh os switch -u && nix develop --command "git add . && git commit -m update"
  just health

test:
  nh os test
  nix flake check
  just health

build:
  nh os build

clean:
  nh clean all --keep 3

gc:
  nix-collect-garbage -d

health:
  systemctl --failed
  journalctl -p 3 -xb --no-pager -n 10 || echo "No recent critical errors"
  df -h /
