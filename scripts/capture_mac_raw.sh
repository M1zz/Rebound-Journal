#!/bin/bash
# 맥 원본 캡처: 창을 1280×800 으로 맞춰 레티나 2560×1600 으로 찍는다.
# 사용법: scripts/capture_mac_raw.sh <앱 경로> [스토어 로케일 …]
#   DEBUG 빌드여야 한다(-shot). 스크린샷 모드는 메모리 저장소만 써서 이 Mac 의 기록에 닿지 않는다.
set -uo pipefail
cd "$(dirname "$0")/.."
APP="$1"; shift
LOCALES=("$@")
[ ${#LOCALES[@]} -eq 0 ] && LOCALES=(ko en-US en-GB cs da de el es fi fr id it ja nb nl pl pt-BR ru sv th tr vi zh-Hans zh-Hant)
SCENES=("01-home:home:16" "02-conversation:conversation:28" "04-records:records:8" "05-friends:settings:8")
for loc in "${LOCALES[@]}"; do
  lang="$loc"; [ "$loc" = "en-US" ] && lang="en"
  mkdir -p "docs/screenshots/raw/$loc"
  for s in "${SCENES[@]}"; do
    IFS=: read name scene wait <<< "$s"
    pkill -x Mochimo; sleep 1
    open -n "$APP" --args -shot "$scene" -AppleLanguages "($lang)" -AppleLocale "${lang//-/_}" -NSQuitAlwaysKeepsWindows NO
    sleep 3
    osascript -e 'tell application "System Events" to tell process "Mochimo"
      set frontmost to true
      set position of window 1 to {160, 60}
      set size of window 1 to {1280, 800}
    end tell' >/dev/null 2>&1
    sleep "$wait"
    screencapture -x -R160,60,1280,800 "docs/screenshots/raw/$loc/mac-$name.png"
    echo "captured $loc $name"
  done
done
pkill -x Mochimo
