{ pkgs, config, ... }:
{
  home.packages = [
    pkgs.vit
    pkgs.taskopen
  ];

  home.file = {
    ".vit/config.ini".text =
      ''
        [keybinding]
        o = :!wr taskopen {TASK_UUID}<Enter>
        i = :!wr task {TASK_UUID} info<Enter>
        ri = :inbox<Enter>
        rs = :someday<Enter>
        rn = :next<Enter>
        [vit]
        theme = stylix
      '';

    # Generate vit theme from Stylix colors following base16 guidelines
    ".vit/theme/stylix.py".text = with config.lib.stylix.colors.withHashtag; ''
      # Auto-generated vit theme from Stylix configuration
      # Following base16 guidelines: base00=bg, base01=lighter_bg, base02=selection, base03=comments, base05=fg, base08=errors, base0D=functions/focus
      # urwid palette format: (name, fg_16color, bg_16color, mono, fg_256color, bg_256color)
      theme = [
          ('list-header', "", "", "", "", ""),
          ('list-header-column', 'white', 'black', "", '${base05}', '${base01}'),  # Default foreground on lighter background
          ('list-header-column-separator', 'dark magenta', 'black', "", '${base03}', '${base01}'),  # Comments color on lighter background
          ('striped-table-row', 'white', 'dark gray', "", '${base05}', '${base02}'),  # Default foreground on selection background
          ('reveal focus', 'black', 'dark magenta', 'standout', '${base00}', '${base0D}'),  # Primary background on focus color (inverted for visibility)
          ('message status', 'white', 'dark magenta', 'standout', '${base05}', '${base0D}'),  # Default foreground on focus/info color
          ('message error', 'white', 'dark red', 'standout', '${base05}', '${base08}'),  # Default foreground on error color
          ('status', 'dark magenta', 'black', "", '${base0E}', '${base00}'),  # Purple on primary background
          ('flash off', 'black', 'black', 'standout', '${base00}', '${base00}'),  # Background on background (invisible)
          ('flash on', 'white', 'black', 'standout', '${base05}', '${base00}'),  # Default foreground on primary background
          ('pop_up', 'white', 'black', "", '${base05}', '${base00}'),  # Default foreground on primary background
          ('button action', 'white', 'dark red', "", '${base05}', '${base08}'),  # Default foreground on error color (for action emphasis)
          ('button cancel', 'dark magenta', 'black', "", '${base03}', '${base01}'),  # Comments color on lighter background
      ]
    '';
  };
}
