#!/usr/bin/env python3
"""App Store 마케팅 스크린샷: 원본 캡처 + 헤드라인 → HTML → 헤드리스 Chrome.

사용법: python3 Scripts/make_marketing_screenshots.py [로케일 ...]     (없으면 전부)

자리
  docs/screenshots/raw/<스토어 로케일>/0N-*.png        원본 캡처 1320x2868 (iPhone 17 Pro Max). 올라가지 않는다
  docs/screenshots/marketing/<스토어 로케일>/0N-*.png  제출본 1242x2688. DeployBar 가 이 폴더를 올린다
  Scripts/marketing_captions.json                     언어별 헤드라인 · 보조 문장 (장 순서대로 5쌍)

원본 다시 찍기: DEBUG 빌드의 `-shot <화면>` 실행 인자 (ZinggumDol/Services/ScreenshotMode.swift)
  01-home ← home · 02-conversation ← conversation · 03-path ← lookBack · 04-records ← records · 05-pebbles ← settings
  xcrun simctl launch <기기> com.leeo.ReboundJournal -shot home -AppleLanguages "(de)" -AppleLocale de_DE

⚠️ 문구는 기계번역하지 않는다. 1장 헤드라인은 검색 결과 그림(make_creative_assets.py 의 SEARCH)과 같은 이야기다.
⚠️ 바탕 · 글자색은 헤더 · 검색 결과 그림과 같다. 다르면 제품 페이지에서 한쪽만 남의 앱처럼 보인다.
"""
import json, pathlib, subprocess, sys, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"
OUT = ROOT / "docs" / "screenshots" / "marketing"
CAPTIONS = json.loads((ROOT / "Scripts" / "marketing_captions.json").read_text(encoding="utf-8"))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688

# (파일 이름, 배치)
SHOTS = [
    ("01-home.png", "hero"),
    ("02-conversation.png", "left"),
    ("03-path.png", "bottom"),
    ("04-records.png", "tilt"),
    ("05-pebbles.png", "hero"),
]

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:#EFF3F3; position:relative;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "Thonburi", sans-serif; }}
.glow {{ position:absolute; border-radius:50%; filter:blur(140px); background:rgba(95,143,147,.12); }}
.text {{ position:absolute; left:90px; right:90px; }}
.headline {{ font-weight:800; color:#232C2B; letter-spacing:-0.03em; line-height:1.14; text-wrap:balance; }}
.sub {{ font-weight:500; color:#566564; font-size:50px; letter-spacing:-0.01em; line-height:1.32; margin-top:34px; text-wrap:balance; }}
:lang(th) .headline, :lang(ja) .headline, :lang(zh) .headline {{ letter-spacing:0; }}
:lang(th) .headline {{ line-height:1.32; }}
:lang(ko) .headline, :lang(ko) .sub {{ word-break:keep-all; }}
.phone {{ position:absolute; background:#17171a; border:4px solid #3a3a3e; padding:24px; border-radius:118px;
  box-shadow: 50px 80px 120px rgba(35,44,43,.22), 16px 26px 44px rgba(35,44,43,.12); }}
.phone img {{ width:100%; display:block; border-radius:94px; }}
"""

LAYOUTS = {
    # 글 위 가운데, 폰 정면 · 아래로 넘침
    "hero": (".text{top:210px;text-align:center}", "left:136px;top:880px;width:970px"),
    # 글 왼쪽 정렬, 폰 오른쪽으로 기울어 넘침
    "left": (".text{top:210px;text-align:left}", "left:250px;top:900px;width:930px;transform:rotate(4deg)"),
    # 폰 위, 글 아래
    "bottom": (".text{bottom:150px;text-align:center}", "left:166px;top:130px;width:910px"),
    # 글 위, 폰 왼쪽으로 기울어 넘침
    "tilt": (".text{top:210px;text-align:center}", "left:80px;top:900px;width:960px;transform:rotate(-5deg)"),
}

# 헤드라인이 적은 줄 수(<br> + 1)를 넘거나 상자를 넘으면 줄인다. 끝까지 안 맞으면 표시하고 멈춘다.
FIT_JS = """
<script>
function lines(el){ return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight)); }
document.fonts.ready.then(() => {
  const h = document.querySelector('.headline'), s = document.querySelector('.sub');
  const want = h.querySelectorAll('br').length + 1;
  let size = 112; h.style.fontSize = size + 'px';
  while (size > 64 && (lines(h) > want || h.scrollWidth > h.clientWidth + 1)) { size -= 4; h.style.fontSize = size + 'px'; }
  let sub = 50;
  while (sub > 36 && lines(s) > 2) { sub -= 2; s.style.fontSize = sub + 'px'; }
  if (lines(h) > want || lines(s) > 2) document.body.dataset.overflow = '1';
  document.body.dataset.done = '1';
});
</script>
"""


def html_lang(locale):
    return {"en-US": "en", "pt-BR": "pt"}.get(locale, locale)


def render(locale):
    captions = CAPTIONS[locale]
    assert len(captions) == len(SHOTS), locale
    out_dir = OUT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    for (name, layout), (headline, sub) in zip(SHOTS, captions):
        src = RAW / locale / name
        if not src.exists():
            raise SystemExit(f"원본 없음: {src}")
        text_css, phone_style = LAYOUTS[layout]
        body = (f'<div class="glow" style="left:-200px;top:700px;width:1600px;height:1600px"></div>'
                f'<div class="phone" style="{phone_style}"><img src="{src.as_uri()}"></div>'
                f'<div class="text"><div class="headline">{headline}</div><div class="sub">{sub}</div></div>')
        page = (f'<!doctype html><html lang="{html_lang(locale)}"><head><meta charset="utf-8">'
                f'<style>{BASE_CSS}{text_css}</style></head><body>{body}{FIT_JS}</body></html>')
        html_path = pathlib.Path(tempfile.gettempdir()) / f"zinggumdol-marketing-{locale}-{name}.html"
        html_path.write_text(page, encoding="utf-8")
        common = ["--headless=new", f"--window-size={W},{H}", "--force-device-scale-factor=1", "--hide-scrollbars",
                  "--disable-gpu", "--virtual-time-budget=3000", "--allow-file-access-from-files"]
        dom = subprocess.run([CHROME, *common, "--dump-dom", html_path.as_uri()],
                             capture_output=True, text=True, timeout=300).stdout
        if 'data-done="1"' not in dom:
            raise SystemExit(f"글 맞추기가 끝나지 않았다: {locale} {name}")
        if 'data-overflow="1"' in dom:
            raise SystemExit(f"글이 넘친다: {locale} {name} - 문구를 줄일 것")
        out_png = out_dir / name
        for _ in range(3):  # Chrome 은 가끔 아무것도 안 그리고 끝난다
            try:
                r = subprocess.run([CHROME, *common, f"--screenshot={out_png}", html_path.as_uri()],
                                   capture_output=True, timeout=300)
            except subprocess.TimeoutExpired:
                continue
            if r.returncode == 0 and out_png.exists():
                break
        else:
            raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
        print(f"rendered {out_png}")
        time.sleep(3)  # 맥을 가볍게 (nice -n 19 로 돌린다)


if __name__ == "__main__":
    for locale in sys.argv[1:] or list(CAPTIONS):
        if locale not in CAPTIONS:
            raise SystemExit(f"모르는 언어: {locale}")
        render(locale)
