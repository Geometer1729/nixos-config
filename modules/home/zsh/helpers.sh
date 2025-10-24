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
	git clone `wl-paste -o`
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
