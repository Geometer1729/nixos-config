# Local text-to-speech with Kokoro, for `echo text | speak` and the OpenCode speech plugin.
{ pkgs, machine, ... }:
let
  # Kokoro 1.0 packaged for sherpa-onnx; the English voices need only its US lexicon.
  kokoro = pkgs.fetchzip {
    name = "kokoro-multi-lang-v1_0";
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_0.tar.bz2";
    hash = "sha256-HKrjB25Dqlu7p000Js6S6+y32h/dDEjn7vQqWnCU74E=";
  };
in
{
  scripts.speech = {
    enable = machine.hasGui;
    directory = ./.;
    extras = with pkgs; [ pipewire playerctl sherpa-onnx ];
    overrides.focused-pane.extras = with pkgs; [ hyprland tmux ];
    runtimeEnv = {
      KOKORO = "${kokoro}";
      # af_heart, Kokoro's best-rated voice.
      KOKORO_SPEAKER = "3";
    };
  };
}
