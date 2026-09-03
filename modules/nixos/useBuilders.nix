{
  programs.ssh.knownHosts.am.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpLa0qnwzKS2Au6VkrfD8Yo7U9udsRJMhzDBxEv6fx0";

  nix = {
    settings = {
      builders-use-substitutes = true;
      # Add am as a substitute server
      substituters = [ "ssh-ng://bbrian@am" ];
      trusted-substituters = [ "ssh-ng://bbrian@am" ];
      trusted-public-keys = [ "am:Z8PSUn37U1JU2UXWxnfHPpMQDrCcXa3oLMvNCVPUz5s=" ];
    };
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "am";
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUtwTGEwcW53ektTMkF1NlZrcmZEOFlvN1U5dWRzUkpNaHpEQnhFdjZmeDAgcm9vdEBhbQo=";
        sshKey = "/home/bbrian/.ssh/id_ed25519";
        sshUser = "bbrian";
        system = "x86_64-linux";
        # Match exactly what the builder machine supports
        supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
        mandatoryFeatures = [ ];
        # Increase speed setting to prefer remote builder
        speedFactor = 2;
        maxJobs = 12;
      }
    ];
  };
}
