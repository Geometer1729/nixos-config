#!/usr/bin/env bash
# Speak stdin aloud with Kokoro. Killing the process group stops it mid-sentence.

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

speak-synthesize "$workdir/speech.wav"
speak-play "$workdir/speech.wav"
