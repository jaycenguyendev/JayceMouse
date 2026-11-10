#!/bin/bash
# Renders the launch video end to end: frames -> soundtrack -> out/JayceMouse-launch.mp4
set -euo pipefail
cd "$(dirname "$0")"

[ -d node_modules ] || npm install --silent
node render.mjs
python3 audio.py
ffmpeg -y -loglevel error -i out/video.mp4 -i out/audio.wav -map 0:v -map 1:a -c:v copy \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:a aac -b:a 256k -ar 48000 -shortest out/JayceMouse-launch.mp4
echo "Done: out/JayceMouse-launch.mp4"
