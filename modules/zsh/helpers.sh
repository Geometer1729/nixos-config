zathura_(){
	\zathura $@ &
}

rm_(){
	\rm -v $@ || \rm -riv $@
}

cd_(){
	\cd $@  && ls -hN --color=auto --group-directories-first
}

fg_(){
  if ( jobs | grep "" || ! [ -f .session.vim ] )
    then
      \fg
    else
      resVim
  fi
}

resVim(){
 vim -S .session.vim -c 'silent exec "!rm .session.vim"'
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
  \nixos-rebuild --flake ~/conf\#$1 --target-host bbrian@$1 --use-remote-sudo $2
}
