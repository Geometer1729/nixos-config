{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    diff-so-fancy.enable = true;
    userEmail = "16kuhnb@gmail.com";
    userName = "Geometer1729";
    extraConfig = {
      push.autoSetupRemote = true;
      merge.conflictstyle = "diff3";
      branch.autoSetupMerge = true;
      credential."https://github.com".helper = "${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gitst.github.com".helper = "${pkgs.gh}/bin/gh auth git-credential";
      credential.helper = "store";
    };
    signing = {
      #signByDefault = true;
      #key = "79C7B4461F8AA7D7CE6239E47889938835D9DD8E";
    };
    aliases = {
      co = "checkout";
      s = "status";
      sw = "switch";
      d = "diff";
      a = "add";
      clean = "clean -fdX"; # this doesn't work :(
    };
  };
  programs.lazygit = {
    enable = true;
    settings = {
      promptToReturnFromSubprocess = false;
    };
  };
}
