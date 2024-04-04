{
	nixModules =
		[ ./hardware.nix
		];
	homeModules = [ ];
	ip = "192.168.12.187";
	builder = false;
  drive = "/dev/sda";
	wifi = {
		enable = true;
		interface = "wlp3s0";
	};
	battery = true;
	system = "x86_64-linux";
}
