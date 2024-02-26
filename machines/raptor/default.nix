{inputs}:
{
	nixModules =
		[ ./hardware.nix
      ./impermanence.nix
      inputs.disko.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
		];
	homeModules =
    [ ./home-impermanence.nix
      inputs.impermanence.nixosModules.home-manager.impermanence
    ];
	ip = "192.168.1.107";
	builder = false;
	wifi = {
		enable = true;
		interface = "wlp3s0";
	};
	battery = true;
	system = "x86_64-linux";
}
