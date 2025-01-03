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
	git clone `xclip -selection clipboard -o`
}

log(){
	$@ &| tee log
}

nixos-deploy(){
  nh os build -H $1
  \nixos-rebuild --flake ~/conf\#$1 --target-host bbrian@$1 --use-remote-sudo $2
}

jqcb(){
  xclip -selection clipboard -o | jq | xclip -selection clipboard -i
}
