#!/bin/bash
# 스토어 원본 캡처 (세로). DEBUG 빌드가 설치돼 있어야 한다(-shot).
#   iphone: iPhone 17 Pro Max 1320×2868 → raw/<로케일>/0N-*.png        (5장)
#   ipad:   iPad Pro 13"     2064×2752 → raw/<로케일>/ipad-0N-*.png   (4장)
# 사용법: scripts/capture_raw.sh <iphone|ipad> <기기 UDID> [스토어 로케일 …]
#   ONLY=02-conversation 처럼 주면 그 장만 찍는다.
set -uo pipefail
cd "$(dirname "$0")/.."
DEVICE="$1"; DEV="$2"; shift 2
LOCALES=("$@")
[ ${#LOCALES[@]} -eq 0 ] && LOCALES=(ko en-US en-GB cs da de el es fi fr id it ja nb nl pl pt-BR ru sv th tr vi zh-Hans zh-Hant)
if [ "$DEVICE" = "ipad" ]; then
  PREFIX="ipad-"
  # 지나온 길은 아이패드에서 늘 옆 판에 있어 따로 찍지 않는다 (맥과 같은 4장).
  SCENES=("01-home:home:16" "02-conversation:conversation:28" "04-records:records:8" "05-friends:settings:8")
else
  PREFIX=""
  SCENES=("01-home:home:16" "02-conversation:writing:36" "03-path:lookBack:8" "04-records:records:8" "05-friends:settings:8")
fi
xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 >/dev/null 2>&1
for loc in "${LOCALES[@]}"; do
  lang="$loc"; [ "$loc" = "en-US" ] && lang="en"
  mkdir -p "docs/screenshots/raw/$loc"
  for s in "${SCENES[@]}"; do
    IFS=: read name scene wait <<< "$s"
    [ -n "${ONLY:-}" ] && [ "$name" != "$ONLY" ] && continue
    xcrun simctl launch --terminate-running-process "$DEV" com.leeo.ReboundJournal \
      -shot "$scene" -AppleLanguages "($lang)" -AppleLocale "${lang//-/_}" >/dev/null
    sleep "$wait"
    # 시뮬레이터는 레포의 기존 파일을 덮어쓰지 못하고 조용히 실패한다. 임시 파일로 찍어 옮긴다.
    tmp="$(mktemp -d)/shot.png"
    if xcrun simctl io "$DEV" screenshot "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "docs/screenshots/raw/$loc/$PREFIX$name.png"
      echo "captured $loc $name"
    else
      echo "✗ failed $loc $name"
    fi
  done
done
