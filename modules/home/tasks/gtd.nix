{ pkgs, lib, ... }:
let
  # Global mapping of column names to their display labels
  columnLabels = {
    id = "ID";
    "entry.age" = "Age";
    "start.age" = "Active";
    priority = "P";
    project = "Project";
    energy = "Energy";
    estimate = "Est";
    description = "Description";
    "description.count" = "Description";
    tags = "Tags";
    urgency = "Urg";
    annotations = "Waiting For";
  };

  # Helper function to generate taskwarrior report configuration
  mkReport = { name, columns, filter, sort ? null, description ? "" }:
    {
      "report.${name}.description" = description;
      "report.${name}.columns" = lib.concatStringsSep "," columns;
      "report.${name}.labels" = lib.concatStringsSep "," (map (c: columnLabels.${c}) columns);
      "report.${name}.filter" = filter;
    } // lib.optionalAttrs (sort != null) {
      "report.${name}.sort" = sort;
    };

  # Convert reports attrset to taskwarrior config
  mkReports = reports:
    lib.foldl' lib.mergeAttrs { }
      (lib.mapAttrsToList (name: cfg: mkReport (cfg // { inherit name; })) reports);

  # Define all reports
  reports = {
    inbox = {
      description = "GTD Inbox - items to process";
      columns = [ "id" "entry.age" "description" ];
      filter = "status:pending -next -waiting -someday";
      sort = "entry+";
    };
    next = {
      description = "GTD Next Actions";
      columns = [ "id" "start.age" "priority" "project" "energy" "estimate" "description.count" "tags" "urgency" ];
      filter = "+next status:pending -@work";
      sort = "urgency-";
    };
    waiting = {
      description = "GTD Waiting For";
      columns = [ "id" "entry.age" "description.count" "annotations" ];
      filter = "+waiting status:pending";
      sort = "entry+";
    };
    someday = {
      description = "GTD Someday/Maybe";
      columns = [ "id" "entry.age" "project" "description.count" ];
      filter = "+someday status:pending -@work";
      sort = "entry+";
    };
    review = {
      description = "GTD Weekly Review";
      columns = [ "id" "project" "tags" "description.count" "urgency" ];
      filter = "status:pending";
      sort = "project+,urgency-";
    };
    computer = {
      description = "Tasks at computer";
      columns = [ "id" "priority" "energy" "estimate" "project" "description.count" "urgency" ];
      filter = "+next +@computer status:pending";
      sort = "urgency-";
    };
    home = {
      description = "Tasks at home";
      columns = [ "id" "priority" "energy" "estimate" "project" "description.count" "urgency" ];
      filter = "+next +@home status:pending";
      sort = "urgency-";
    };
    errands = {
      description = "Errands to run";
      columns = [ "id" "priority" "energy" "estimate" "project" "description.count" "urgency" ];
      filter = "+next +@errands status:pending";
      sort = "urgency-";
    };
    work = {
      description = "Tasks at work";
      columns = [ "id" "priority" "energy" "estimate" "project" "description.count" "urgency" ];
      filter = "+next +@work status:pending";
      sort = "urgency-";
    };
    high = {
      description = "High energy tasks";
      columns = [ "id" "estimate" "project" "description.count" "urgency" "tags" ];
      filter = "+next energy:H status:pending";
      sort = "urgency-";
    };
    low = {
      description = "Low energy tasks";
      columns = [ "id" "estimate" "project" "description.count" "urgency" "tags" ];
      filter = "+next energy:L status:pending";
      sort = "urgency-";
    };
  };
in
{
  # GTD helper scripts moved to modules/home/scripts/

  programs.taskwarrior.config = {
    # GTD User Defined Attributes
    "uda.energy.type" = "string";
    "uda.energy.label" = "Energy";
    "uda.energy.values" = "H,M,L";

    "uda.estimate.type" = "string";
    "uda.estimate.label" = "Est";

    # Urgency adjustments for GTD tags
    "urgency.user.tag.next.coefficient" = "5.0"; # Next actions are important
    "urgency.user.tag.waiting.coefficient" = "-2.0"; # Waiting items less urgent
    "urgency.user.tag.someday.coefficient" = "-5.0"; # Someday items not urgent

    # GTD Reports
  } // mkReports reports;

  # TODO these all feel kinda silly
  programs.zsh.shellAliases = {
    # GTD workflow aliases
    inbox = "task add"; # Quick capture to inbox
    review = "gtd-review"; # Weekly review
    stats = "gtd-stats"; # GTD overview stats



    # View specific lists
    tin-view = "task inbox"; # View inbox
    tnext = "task next"; # View next actions
    twait = "task waiting"; # View waiting items
    tsomeday = "task someday"; # View someday/maybe
    tproj = "task projects"; # View projects summary

    # Context-based views
    tcomputer = "task computer"; # Tasks at computer
    thome = "task home"; # Tasks at home
    terrands = "task errands"; # Errands to run
    twork = "task work"; # Tasks at work

    # Energy-based views
    thigh = "task high"; # High energy tasks
    tlow = "task low"; # Low energy tasks

    # Quick actions
    tnow = "task +next start"; # Start a next action
    tdone = "task done"; # Complete a task
  };
}
