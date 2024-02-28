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
      ./firefox.nix
      inputs.impermanence.nixosModules.home-manager.impermanence
      inputs.nur.nixosModules.nur
    ];
	ip = "192.168.1.106";
	builder = false;
	wifi = {
		enable = true;
		interface = "wlp3s0";
	};
	battery = true;
	system = "x86_64-linux";
}
