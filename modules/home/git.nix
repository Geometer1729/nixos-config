{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      push.autoSetupRemote = true;
      push.default = "current";
      advice.forceDeleteBranch = false;
      merge.conflictstyle = "diff3";
      branch.autoSetupMerge = true;
      credential."https://github.com".helper = "${pkgs.gh}/bin/gh auth git-credential";
      credential."https://gitst.github.com".helper = "${pkgs.gh}/bin/gh auth git-credential";
      credential.helper = "store --file ~/.local/share/git/credentials";
      alias = {
        co = "checkout";
        s = "status";
        sw = "switch";
        d = "diff";
        a = "add";
        cl = "clean -fdX";
        recommit = "commit -eF .git/COMMIT_EDITMSG";
      };
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
      git.push.forceWithLease = true;
    };
  };
}
