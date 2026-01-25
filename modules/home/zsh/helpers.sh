zathura_(){
	\zathura $@ &
}

rm_(){
	\rm -v $@ || \rm -riv $@
}

cd_(){
	\cd $@  && ls -hN --color=auto --group-directories-first
}

loop(){
	while true
	do
		$@
	done
}

tillFail(){
	while $@
	do
		echo ran
	done
}

grab(){
	git clone `wl-paste`
}

log(){
	$@ &| tee log
}

nixos-deploy(){
  nh os build -H $1
  \nixos-rebuild --flake ~/conf\#$1 --target-host bbrian@$1 --sudo $2
}

jqcb(){
  wl-paste | jq | wl-copy
}

git_(){
  if [[ "$1" == "push" ]]; then
    local args=("push")
    shift
    for arg in "$@"; do
      if [[ "$arg" == "--force" || "$arg" == "-f" ]]; then
        args+=("--force-with-lease")
      else
        args+=("$arg")
      fi
    done
    command git "${args[@]}"
  else
    command git "$@"
  fi
}
