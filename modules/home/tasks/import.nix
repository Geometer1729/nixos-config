{ config, lib, pkgs, ... }:
let
  cfg = config.tasks.import;
  py = pkgs.python3Packages;

  # nixpkgs builds taskw against Taskwarrior 2, so bugwarrior would write
  # pending.data files that Taskwarrior 3 never reads.
  taskw = (py.taskw.override { taskwarrior2 = config.programs.taskwarrior.package; }).overridePythonAttrs (old: {
    # Bracket matching in descriptions fails; bugwarrior only filters on URLs.
    disabledTests = (old.disabledTests or [ ]) ++ [ "test_filtering_brace" ];
  });
  bugwarrior = py.bugwarrior.override { inherit taskw; };

  # Imports skip the inbox: each lands already triaged into a GTD list, with
  # contexts, and +agent so the startable report offers it to an agent.
  contexts = [ "agent" "@computer" "@home" ];
  # A ready PR waits on its reviewers; a draft is still mine to finish.
  prTags = contexts ++ [ "{{ 'next' if githubdraft else 'waiting' }}" ];

  github = {
    service = "github";
    login = "Geometer1729";
    # gh's own login token. A narrower one buys nothing: narvi can already
    # SSH into every host as root.
    token = "@oracle:eval:cat /run/secrets/github_token";
    include_user_repos = false;
    include_user_issues = false;
    default_priority = "";
    description_template = "{{githubrepo}}#{{githubnumber}}: {{githubtitle}}";
  };

  settings = {
    general = {
      targets = [ "linear" "work_prs" "work_reviews" "personal_prs" ];
      annotation_comments = false;
      # Set on import only, so triage edits stick.
      static_fields = [ "priority" "project" ];
      merge_tags = false;
    };
    linear = {
      service = "linear";
      api_token = "@oracle:eval:cat /run/secrets/linear_api_key";
      # task-import fills this in; this repo is public.
      only_if_assigned = "@LINEAR_EMAIL@";
      status_types = [ "unstarted" "started" ];
      add_tags = [ "@work" "next" ] ++ contexts;
      default_priority = "";
      description_template = "{{linearidentifier}}: {{lineartitle}}";
    };
    # Scoped by owner: author:@me alone also finds stale PRs at old jobs.
    work_prs = github // {
      query = "is:open is:pr author:@me org:geosurge-ai";
      add_tags = [ "@work" ] ++ prTags;
    };
    # Completes by itself once reviewed, by dropping out of the query.
    work_reviews = github // {
      query = "is:open is:pr review-requested:@me org:geosurge-ai";
      add_tags = [ "@work" "next" ] ++ contexts;
      description_template = "Review ${github.description_template}";
    };
    personal_prs = github // {
      query = "is:open is:pr author:@me user:Geometer1729";
      add_tags = prTags;
      project_template = "{{ 'conf' if githubrepo == 'Geometer1729/nixos-config' else project }}";
    };
  };
  configFile = (pkgs.formats.toml { }).generate "bugwarrior.toml" settings;

  udas = pkgs.runCommand "bugwarrior-udas" { nativeBuildInputs = [ bugwarrior ]; } ''
    touch taskrc
    HOME=$PWD TASKRC=$PWD/taskrc BUGWARRIORRC=${configFile} bugwarrior uda > $out
  '';
in
{
  options.tasks.import.enable = lib.mkEnableOption "importing Linear issues and GitHub PRs into Taskwarrior";

  config = lib.mkMerge [
    {
      # Every host, so imported tasks can be filtered and shown anywhere.
      programs.taskwarrior.extraConfig = "include ${udas}";

      scripts.tasks.overrides.task-import = {
        inherit (cfg) enable;
        extras = [ bugwarrior ];
        runtimeEnv.BUGWARRIOR_CONFIG = "${configFile}";
      };
    }
    (lib.mkIf cfg.enable {
      systemd.user.services.task-import = {
        Unit = {
          Description = "Import Linear issues and GitHub PRs into Taskwarrior";
          After = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${config.scripts.tasks.packages.task-import}/bin/task-import";
        };
      };

      systemd.user.timers.task-import = {
        Unit.Description = "Import Linear issues and GitHub PRs every 10 minutes";
        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = "10min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
  ];
}
