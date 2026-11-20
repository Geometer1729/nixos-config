# Filters Claude Code's stream-json stdin, one raw line at a time.
#
# When OpenCode's Claude Agent provider rebuilds a Claude session, it replays the
# OpenCode history as one user message. Images and PDFs that tools returned go in
# as real media blocks after an "Attached media from tool result:" line, so
# Claude Code treats them as freshly pasted and agents re-read them, doubling the
# copies on every replay (anomalyco/opencode#62085). Swap that media for a note.
# Every other line, including any that fail to parse, passes through unchanged.

def marker: "Attached media from tool result:";

def is_text($text): .type == "text" and .text == $text;

def is_media: .type == "image" or .type == "document";

def note:
  (.source.media_type // .type) as $kind
  | {type: "text", text: "[\($kind) from the tool result above, left out of this replay. The user did not attach it; repeat that tool call to see it again.]"};

# The replay wraps each message in "<role>" text blocks, so the media OpenCode
# moved out of tool results is the run of media blocks right after "<user>",
# then the marker. Media the user pasted has no marker and is kept.
def strip_tool_media:
  [foreach .[] as $block ({previous: null, media: false};
      .media = if $block | is_media then .media
        else ($block | is_text(marker)) and (.previous | is_text("<user>")) end
      | .previous = $block;
      if .media and ($block | is_media) then $block | note else $block end)];

. as $line
| if contains(marker) then
    try (
      fromjson
      | if .type == "user" and (.message.content | type) == "array" then
          (.message.content | strip_tool_media) as $content
          | if $content == .message.content then $line
            else .message.content = $content | tojson end
        else $line end)
    catch $line
  else $line end
