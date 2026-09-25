{ pkgs, ... }:
let
  # Pinned to a repo revision so the hash stays valid.
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin";
    sha256 = "0sdwwblbfy9qjkjjxxvyfn47rx3y6pm1wfdcjfcidsrq9mvhziqz";
  };
in
{
  scripts.dictation = {
    directory = ./.;
    extras = with pkgs; [ pipewire whisper-cpp-vulkan wtype ];
    runtimeEnv.DICTATION_MODEL = "${model}";
  };
}
