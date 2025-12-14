{ pkgs, ... }:
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
    "report.inbox.description" = "GTD Inbox - items to process";
    "report.inbox.columns" = "id,entry.age,description";
    "report.inbox.labels" = "ID,Age,Description";
    "report.inbox.filter" = "status:pending -next -waiting -someday";
    "report.inbox.sort" = "entry+";

    "report.next.description" = "GTD Next Actions";
    "report.next.columns" = "id,start.age,priority,project,energy,estimate,description.count,tags,urgency";
    "report.next.labels" = "ID,Active,P,Project,Energy,Est,Description,Tags,Urg";
    "report.next.filter" = "+next status:pending";
    "report.next.sort" = "urgency-";

    "report.waiting.description" = "GTD Waiting For";
    "report.waiting.columns" = "id,entry.age,description.count,annotations";
    "report.waiting.labels" = "ID,Age,Description,Waiting For";
    "report.waiting.filter" = "+waiting status:pending";
    "report.waiting.sort" = "entry+";

    "report.someday.description" = "GTD Someday/Maybe";
    "report.someday.columns" = "id,entry.age,project,description.count";
    "report.someday.labels" = "ID,Age,Project,Description";
    "report.someday.filter" = "+someday status:pending";
    "report.someday.sort" = "entry+";

    "report.review.description" = "GTD Weekly Review";
    "report.review.columns" = "id,project,tags,description.count,urgency";
    "report.review.labels" = "ID,Project,Tags,Description,Urg";
    "report.review.filter" = "status:pending";
    "report.review.sort" = "project+,urgency-";

    # Context-based reports
    "report.computer.description" = "Tasks at computer";
    "report.computer.filter" = "+next +@computer status:pending";
    "report.computer.columns" = "id,priority,energy,estimate,project,description.count,urgency";
    "report.computer.labels" = "ID,P,Energy,Est,Project,Description,Urg";
    "report.computer.sort" = "urgency-";

    "report.home.description" = "Tasks at home";
    "report.home.filter" = "+next +@home status:pending";
    "report.home.columns" = "id,priority,energy,estimate,project,description.count,urgency";
    "report.home.labels" = "ID,P,Energy,Est,Project,Description,Urg";
    "report.home.sort" = "urgency-";

    "report.errands.description" = "Errands to run";
    "report.errands.filter" = "+next +@errands status:pending";
    "report.errands.columns" = "id,priority,energy,estimate,project,description.count,urgency";
    "report.errands.labels" = "ID,P,Energy,Est,Project,Description,Urg";
    "report.errands.sort" = "urgency-";

    # Energy-based reports
    "report.high.description" = "High energy tasks";
    "report.high.filter" = "+next energy:H status:pending";
    "report.high.columns" = "id,tags,estimate,project,description.count,urgency";
    "report.high.labels" = "ID,Tags,Est,Project,Description,Urg";
    "report.high.sort" = "urgency-";

    "report.low.description" = "Low energy tasks";
    "report.low.filter" = "+next energy:L status:pending";
    "report.low.columns" = "id,tags,estimate,project,description.count,urgency";
    "report.low.labels" = "ID,Tags,Est,Project,Description,Urg";
    "report.low.sort" = "urgency-";
  };

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

    # Energy-based views
    thigh = "task high"; # High energy tasks
    tlow = "task low"; # Low energy tasks

    # Quick actions
    tnow = "task +next start"; # Start a next action
    tdone = "task done"; # Complete a task
  };
}
