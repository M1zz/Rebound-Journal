#!/bin/bash
#
# 배포 전 검사 — 징검돌 (Rebound Journal)
#
# DeployBar 가 아카이브하기 전에 부른다. 0 이 아닌 값으로 끝나면 배포가 멈춘다.
#
# ⚠️ 이 프로젝트에는 테스트 타깃이 없다(`xcodebuild -list` 의 Targets 는
#    Rebound Journal 과 ReboundWidget 뿐). 그래서 여기서는 테스트를 돌리지 못하고
#    "Release 로 두 타깃이 컴파일되는가" 까지만 확인한다.
#    테스트 타깃을 추가하면 아래 '테스트' 절의 주석을 풀면 된다.
#
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="Rebound Journal.xcodeproj"
SCHEME="Rebound Journal"
DESTINATION="generic/platform=iOS"

echo "▸ 배포 전 검사 시작"

# ── 1. 커밋되지 않은 변경이 없는지
# 배포된 빌드와 저장소 내용이 어긋나면 나중에 무엇을 올렸는지 되짚을 수 없다.
if [ -n "$(git status --porcelain)" ]; then
  echo "✗ 커밋되지 않은 변경이 있습니다:"
  git status --short
  exit 1
fi
echo "  ✓ 작업 트리 깨끗함"

# ── 2. 릴리즈노트에 이번 버전 절이 있는지
VERSION=$(grep -m1 '^MARKETING_VERSION' Config/Version.xcconfig | sed 's/.*= *//' | tr -d ' ')
if ! grep -qE "^## v?${VERSION}( |\$|\()" RELEASE_NOTES.md; then
  echo "✗ RELEASE_NOTES.md 에 '## ${VERSION}' 절이 없습니다"
  exit 1
fi
echo "  ✓ 릴리즈노트에 ${VERSION} 절 있음"

# ── 3. 문자열 카탈로그에 빈 번역이 없는지
# 비어 있으면 외국 사용자에게 한국어가 그대로 보인다.
python3 - <<'PY'
import json, sys
BAD = {"new", "stale", "needs_review", "needs_translation"}
problems = []
for path in ("Localizable.xcstrings", "InfoPlist.xcstrings"):
    data = json.load(open(path, encoding="utf-8"))
    for key, entry in data["strings"].items():
        locs = entry.get("localizations", {})
        if not locs:
            problems.append(f"{path}: '{key[:40]}' 현지화 없음")
            continue
        def walk(node):
            if not isinstance(node, dict):
                return
            unit = node.get("stringUnit")
            if unit is not None:
                if unit.get("state") in BAD or not unit.get("value"):
                    problems.append(f"{path}: '{key[:40]}' 비었거나 미완료")
            for name, child in node.items():
                if name != "stringUnit":
                    walk(child)
        for node in locs.values():
            walk(node)
if problems:
    print("✗ 번역 구멍:")
    for p in problems[:20]:
        print("   ", p)
    sys.exit(1)
print("  ✓ 번역 구멍 없음")
PY

# ── 4. Release 컴파일 확인 (테스트 타깃이 생기기 전까지의 최소선)
echo "  · Release 빌드 확인 중…"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  -quiet
echo "  ✓ Release 빌드 통과"

# ── 테스트 (테스트 타깃을 추가하면 주석을 풀 것)
# xcodebuild test \
#   -project "$PROJECT" \
#   -scheme "$SCHEME" \
#   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
#   -quiet

echo "▸ 배포 전 검사 통과"
