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
    base = "en_US.UTF-8";
    messages = "en_US.UTF-8";
    time = "en_US.UTF-8";
    numeric = "en_US.UTF-8";
    monetary = "en_US.UTF-8";
    paper = "en_US.UTF-8";
    name = "en_US.UTF-8";
    address = "en_US.UTF-8";
    telephone = "en_US.UTF-8";
    measurement = "en_US.UTF-8";
  };

  home.sessionVariables = {
    LANGUAGE = "en_US:en";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
  };

  # KDE rewrites this file, so Home Manager cannot safely use a fixed backup name.
  gtk.gtk2.force = true;

  home.packages = with pkgs; [
    google-chrome
    fcitx5
    qt6Packages.fcitx5-chinese-addons
    qt6Packages.fcitx5-configtool
    kdePackages.fcitx5-qt
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  xdg.configFile = {
    "plasma-localerc" = {
      force = true;
      text = ''
        [Formats]
        LANG=en_US.UTF-8

        [Translations]
        LANGUAGE=en_US
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
