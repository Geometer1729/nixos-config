# Local text-to-speech with Kokoro, for `echo text | speak` and the OpenCode speech
# plugin, which synthesizes with speak-synthesize ahead of playing with speak-play.
{ flake, config, pkgs, machine, ... }:
let
  # Kokoro 1.0 packaged for sherpa-onnx; the English voices need only its US lexicon.
  inherit (flake.inputs) kokoro;
in
{
  scripts.speech = {
    enable = machine.hasGui;
    directory = ./.;
    extras = with pkgs; [ pipewire playerctl sherpa-onnx ];
    overrides.speak.extras = with config.scripts.speech.packages; [ speak-synthesize speak-play ];
    overrides.focused-pane.extras = with pkgs; [ hyprland tmux ];
    runtimeEnv = {
      KOKORO = "${kokoro}";
      # af_heart, Kokoro's best-rated voice.
      KOKORO_SPEAKER = "3";
    };
  };
}
