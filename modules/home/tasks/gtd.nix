{ pkgs, ... }:
let
  # GTD helper scripts
  process = pkgs.writeShellApplication {
    name = "process";
    runtimeInputs = [ pkgs.taskwarrior3 pkgs.fzf ];
    text = ''
      set -x

      # Process inbox - GTD triage workflow
      echo "=== GTD INBOX PROCESSING ==="
      echo ""
      task inbox

      while true; do
        echo ""
        echo "Select task to process (Ctrl-C to exit):"
        SELECTED=$(task status:pending -next -waiting -someday export | ${pkgs.jq}/bin/jq -r '.[] | "\(.id) \(.description)"' | fzf --prompt="Process: " --preview 'task {} info' --preview-window=right:60%)

        if [ -z "$SELECTED" ]; then
          echo "Processing complete!"
          exit 0
        fi

        TASK_ID=$(echo "$SELECTED" | awk '{print $1}')

        echo ""
        echo "What is it? (1-5)"
        echo "  1) Actionable - Next action (+next)"
        echo "  2) Waiting for someone/something (+waiting)"
        echo "  3) Someday/Maybe (+someday)"
        echo "  4) Multi-step project (assign project name)"
        echo "  5) Delete/Not actionable"
        echo ""
        read -r -p "Choice: " choice

        echo "$TASK_ID"

        case $choice in
          1)
            task "$TASK_ID" modify +next
            read -r -p "Context (@computer/@home/@errands/@anywhere): " context
            if [ -n "$context" ]; then
              task "$TASK_ID" modify context:"$context"
            fi
            read -r -p "Energy level (H/M/L): " energy
            if [ -n "$energy" ]; then
              task "$TASK_ID" modify energy:"$energy"
            fi
            read -r -p "Time estimate (e.g., 15m, 1h): " time
            if [ -n "$time" ]; then
              task "$TASK_ID" modify estimate:"$time"
            fi
            ;;
          2)
            task "$TASK_ID" modify +waiting
            read -r -p "Waiting for (who/what): " waitfor
            if [ -n "$waitfor" ]; then
              task "$TASK_ID" annotate "Waiting for: $waitfor"
            fi
            ;;
          3)
            task "$TASK_ID" modify +someday
            ;;
          4)
            read -r -p "Project name: " project
            if [ -n "$project" ]; then
              task "$TASK_ID" modify project:"$project"
            fi
            echo "Remember to add next actions for this project!"
            ;;
          5)
            task "$TASK_ID" delete
            ;;
          *)
            echo "Invalid choice, skipping..."
            ;;
        esac
      done
    '';
  };

  gtd-review = pkgs.writeShellApplication {
    name = "gtd-review";
    runtimeInputs = [ pkgs.taskwarrior3 ];
    text = ''
      # Weekly GTD review
      echo "=== GTD WEEKLY REVIEW ==="
      echo ""
      echo "1. INBOX (should be empty after processing):"
      task inbox
      echo ""
      read -r -p "Press Enter to continue..."

      echo ""
      echo "2. NEXT ACTIONS (review and update):"
      task next
      echo ""
      read -r -p "Press Enter to continue..."

      echo ""
      echo "3. WAITING FOR (follow up if needed):"
      task waiting
      echo ""
      read -r -p "Press Enter to continue..."

      echo ""
      echo "4. PROJECTS (ensure each has a next action):"
      task projects
      echo ""
      read -r -p "Press Enter to continue..."

      echo ""
      echo "5. SOMEDAY/MAYBE (anything ready to activate?):"
      task someday
      echo ""
      echo "Review complete!"
    '';
  };

  gtd-stats = pkgs.writeShellApplication {
    name = "gtd-stats";
    runtimeInputs = [ pkgs.taskwarrior3 ];
    text = ''
      echo "=== GTD OVERVIEW ==="
      echo ""
      echo "Inbox:       $(task status:pending -next -waiting -someday count) tasks"
      echo "Next:        $(task +next status:pending count) tasks"
      echo "Waiting:     $(task +waiting status:pending count) tasks"
      echo "Someday:     $(task +someday status:pending count) tasks"
      echo ""
      echo "Total pending: $(task status:pending count) tasks"
      echo "Completed this week: $(task status:completed end.after:today-7days count) tasks"
    '';
  };
in
{
  home.packages = [
    process
    gtd-review
    gtd-stats
  ];

  programs.taskwarrior.config = {
    # GTD User Defined Attributes
    "uda.context.type" = "string";
    "uda.context.label" = "Context";
    "uda.context.values" = "@computer,@home,@errands,@anywhere";
    "uda.context.default" = "@anywhere";

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
    "report.next.columns" = "id,start.age,priority,project,context,energy,estimate,tags,description.count,urgency";
    "report.next.labels" = "ID,Active,P,Project,Context,Energy,Est,Tags,Description,Urg";
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
    "report.computer.filter" = "+next context:@computer status:pending";
    "report.computer.columns" = "id,priority,energy,estimate,project,description.count,urgency";
    "report.computer.labels" = "ID,P,Energy,Est,Project,Description,Urg";
    "report.computer.sort" = "urgency-";

    "report.home.description" = "Tasks at home";
    "report.home.filter" = "+next context:@home status:pending";
    "report.home.columns" = "id,priority,energy,estimate,project,description.count,urgency";
    "report.home.labels" = "ID,P,Energy,Est,Project,Description,Urg";
    "report.home.sort" = "urgency-";

    "report.errands.description" = "Errands to run";
    "report.errands.filter" = "+next context:@errands status:pending";
    "report.errands.columns" = "id,priority,energy,estimate,project,description.count,urgency";
    "report.errands.labels" = "ID,P,Energy,Est,Project,Description,Urg";
    "report.errands.sort" = "urgency-";

    # Energy-based reports
    "report.high.description" = "High energy tasks";
    "report.high.filter" = "+next energy:H status:pending";
    "report.high.columns" = "id,context,estimate,project,description.count,urgency";
    "report.high.labels" = "ID,Context,Est,Project,Description,Urg";
    "report.high.sort" = "urgency-";

    "report.low.description" = "Low energy tasks";
    "report.low.filter" = "+next energy:L status:pending";
    "report.low.columns" = "id,context,estimate,project,description.count,urgency";
    "report.low.labels" = "ID,Context,Est,Project,Description,Urg";
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
