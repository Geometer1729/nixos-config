{ ... }:
{
  programs.starship =
    {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = false;
        right_format = "";
        format =
          "$status$username$hostname$directory$git_branch$git_status$memory_usage$time$nix_shell\n$character";
        character.format = "[❯](bold green)";
        status.disabled = false;
        nix_shell =
          {
            format = "[$symbol]($style) ";
            style = "bold cyan";
          };
        directory =
          {
            truncation_length = 5;
            format = "[$path]($style)[$lock_symbol]($lock_style) ";
          };
        git_branch =
          {
            format = "[$symbol$branch(:$remote_branch)]($style) ";
            style = "bold yellow";
            symbol = "🏷 ";
            truncation_length = 20;
            truncation_symbol = "…";
          };
        git_status =
          {
            conflicted = "⚔️";
            ahead = "🏎️💨\${count}";
            behind = "🐢×\${count}";
            diverged = "🔱🏎️💨\${ahead_count}🐢\${behind_count}";
            untracked = "🛤️\${count}";
            stashed = "📦";
            modified = "📝×\${count}";
            staged = "🗃️×\${count}";
            renamed = "[➡](bold green)×\${count}";
            deleted = "🗑️×\${count}";
            style = "bright-white";
            format = "$all_status$ahead_behind ";
          };

        username =
          {
            style_root = "bold red";
            style_user = "bold green";
            format = "[$user]($style)[@](bold white)";
            show_always = true;
            disabled = false;
          };

        hostname =
          {
            ssh_only = false;
            format = "[$hostname]($style)[:](bold white)";
            trim_at = "-";
            style = "bold yellow";
            disabled = false;
          };

        memory_usage =
          {
            threshold = 50;
            format = "[\${ram_pct}]($style)[$symbol]($style)";
            disabled = false;
          };

        time =
          {
            format = "[\${time}]($style)";
            disabled = false;
          };
      };
    };
}
