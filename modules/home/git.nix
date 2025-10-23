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
      signByDefault = true;
      key = "0xA1314A37485AD93E"; # YubiKey signing key
      # On a new machine with YubiKey plugged in, run:
      #   gpg --recv-keys A1314A37485AD93E
      #   gpg-connect-agent "learn --force" /bye
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
