#!/bin/sh
# Builds the firmware with the current git commit stamped in, and copies the
# resulting hex to where the Control Panel's Flash Firmware button looks.
# Commit first: uncommitted changes in the firmware folder add "-dirty".
set -e
cd "$(dirname "$0")"
SKETCH=RRST_Teensy_4_version_TMC2209
HASH=$(git rev-parse --short HEAD)
if [ -n "$(git status --porcelain -- "$SKETCH")" ]; then HASH="$HASH-dirty"; fi
printf '#define GIT_COMMIT "%s"\n' "$HASH" > "$SKETCH/git_commit.h"
BUILD=$(mktemp -d)
arduino-cli compile --fqbn teensy:avr:teensy40 \
  --library "$SKETCH/TeensyStep4-main" --output-dir "$BUILD" "$SKETCH"
cp "$BUILD/$SKETCH.ino.hex" RRST_Control_Panel/firmware/RRST_Teensy_4_version_TMC2209.hex
rm -rf "$BUILD"
echo "Built firmware for commit $HASH"
