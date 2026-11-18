#!/bin/bash
# 아이패드 원본 캡처: iPad Pro 13" 시뮬레이터 2064×2752 (세로).
# 사용법: scripts/capture_ipad_raw.sh <기기 UDID> [스토어 로케일 …]   — DEBUG 빌드가 설치돼 있어야 한다(-shot).
set -uo pipefail
cd "$(dirname "$0")/.."
DEV="$1"; shift
LOCALES=("$@")
[ ${#LOCALES[@]} -eq 0 ] && LOCALES=(ko en-US en-GB cs da de el es fi fr id it ja nb nl pl pt-BR ru sv th tr vi zh-Hans zh-Hant)
# 지나온 길은 아이패드에서 늘 옆 판에 있어 따로 찍지 않는다 (맥과 같은 4장).
SCENES=("01-home:home:16" "02-conversation:conversation:28" "04-records:records:8" "05-friends:settings:8")
xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 >/dev/null 2>&1
for loc in "${LOCALES[@]}"; do
  lang="$loc"; [ "$loc" = "en-US" ] && lang="en"
  mkdir -p "docs/screenshots/raw/$loc"
  for s in "${SCENES[@]}"; do
    IFS=: read name scene wait <<< "$s"
    xcrun simctl launch --terminate-running-process "$DEV" com.leeo.ReboundJournal \
      -shot "$scene" -AppleLanguages "($lang)" -AppleLocale "${lang//-/_}" >/dev/null
    sleep "$wait"
    xcrun simctl io "$DEV" screenshot "docs/screenshots/raw/$loc/ipad-$name.png" >/dev/null 2>&1
    echo "captured $loc $name"
  done
done
