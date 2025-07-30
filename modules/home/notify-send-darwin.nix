{ pkgs }:

pkgs.writeShellApplication {
  name = "notify-send";
  text = ''
    # Darwin-compatible notify-send using osascript
    # Parse notify-send arguments and convert to osascript
    
    TITLE=""
    MESSAGE=""
    
    while [[ $# -gt 0 ]]; do
      case $1 in
        -u|--urgency|--icon|--app-name|-t|--expire-time)
          # Skip unsupported options and their values
          shift 2
          ;;
        *)
          if [[ -z "$TITLE" ]]; then
            TITLE="$1"
          elif [[ -z "$MESSAGE" ]]; then
            MESSAGE="$1"
          fi
          shift
          ;;
      esac
    done
    
    # Use title as message if no message provided
    if [[ -z "$MESSAGE" ]]; then
      MESSAGE="$TITLE"
      TITLE=""
    fi
    
    # Build osascript command
    if [[ -n "$TITLE" ]]; then
      osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
    else
      osascript -e "display notification \"$MESSAGE\""
    fi
  '';
}
