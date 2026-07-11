{ flake, lib, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  home.stateVersion = "25.05";
  home.username = "yixin";
  home.homeDirectory = "/home/yixin";

  imports = with self.homeModules; [
    inputs.nixvim.homeModules.nixvim

    # GUI applications
    ghostty
    ranger

    # System configuration
    system
    systemd-failure-notifications
    desktop
    development
    media
    communication
    gaming

    # Core functionality
    nvim
    scripts
    tmux
    zsh
    webapps
  ];

  home.language = {
    base = "zh_CN.UTF-8";
    messages = "zh_CN.UTF-8";
    time = "zh_CN.UTF-8";
    numeric = "zh_CN.UTF-8";
    monetary = "zh_CN.UTF-8";
    paper = "zh_CN.UTF-8";
    name = "zh_CN.UTF-8";
    address = "zh_CN.UTF-8";
    telephone = "zh_CN.UTF-8";
    measurement = "zh_CN.UTF-8";
  };

  home.sessionVariables = {
    LANGUAGE = "zh_CN:zh";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
  };

  home.packages = with pkgs; [
    google-chrome
    fcitx5
    qt6Packages.fcitx5-chinese-addons
    qt6Packages.fcitx5-configtool
    kdePackages.fcitx5-qt
  ];

  xdg.configFile = {
    "plasma-localerc" = {
      force = true;
      text = ''
        [Formats]
        LANG=zh_CN.UTF-8

        [Translations]
        LANGUAGE=zh_CN
      '';
    };
    "fcitx5/profile" = {
      force = true;
      text = ''
        [Groups/0]
        Name=Default
        Default Layout=us
        DefaultIM=pinyin

        [Groups/0/Items/0]
        Name=keyboard-us
        Layout=

        [Groups/0/Items/1]
        Name=pinyin
        Layout=

        [GroupOrder]
        0=Default
      '';
    };
  };

  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx5 input method";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.fcitx5}/bin/fcitx5";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };

  services.ssh-agent.enable = true;
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

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

  # Disable speech-dispatcher - comes as a dependency but not needed
  systemd.user.services.speech-dispatcher = lib.mkForce { };
  systemd.user.sockets.speech-dispatcher = lib.mkForce { };
}
