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

logThis(){
	$@ &| tee log
}

memClear(){
	sudo rm -rf /tmp/*
	sudo swapoff -a
	sudo swapon -a
}

nixos-deploy(){
  nh os build -H $1
  \nixos-rebuild --flake ~/conf\#$1 --target-host bbrian@$1 --use-remote-sudo $2
}

try(){
  pkg=$1
  cmd=$@
  nix-shell -p $pkg --run "${cmd}"
}
