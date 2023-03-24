{ ... }:
{
    programs.git = {
      enable=true;
      userEmail = "16kuhnb@gmail.com";
      userName = "Geometer1729";
      extraConfig = {
        push.autoSetupRemote=true;
        merge.conflictstyle="diff3";
        branch.autoSetupMerge=true;
      };
      signing = {
        signByDefault = true;
        key = "79C7B4461F8AA7D7CE6239E47889938835D9DD8E";
      };
      aliases = {
        co = "checkout";
        st = "status";
        s = "switch";
      };
    };
}
