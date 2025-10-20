{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.email = "16kuhnb@gmail.com";
      user.name = "Geometer1729";
      push.autoSetupRemote = true;
      merge.conflictstyle = "diff3";
      branch.autoSetupMerge = true;
      credential."https://github.com".helper = "${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gitst.github.com".helper = "${pkgs.gh}/bin/gh auth git-credential";
      credential.helper = "store";
      alias = {
        co = "checkout";
        s = "status";
        sw = "switch";
        d = "diff";
        a = "add";
        clean = "clean -fdX"; # this doesn't work :(
      };
    };
    signing = {
      #signByDefault = true;
      #key = "79C7B4461F8AA7D7CE6239E47889938835D9DD8E";
    };
  };
  programs.diff-so-fancy = {
    enable = true;
    enableGitIntegration = true;
  };
  programs.lazygit = {
    enable = true;
    settings = {
      promptToReturnFromSubprocess = false;
    };
  };
}
