#!/usr/bin/env python3
"""아이패드 · 맥 App Store 스크린샷: 원본 캡처 + 헤드라인 → HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_wide_screenshots.py <ipad|mac> [로케일 ...]     (없으면 전부)

아이폰 것(make_marketing_screenshots.py)과 같은 바탕 · 글꼴 · 문구(marketing_captions.json)를 쓴다.
제품 페이지에서 기기마다 다른 앱처럼 보이지 않게.

자리
  raw/<로케일>/ipad-0N-*.png   원본 2064×2752 (iPad Pro 13" 시뮬레이터)
  raw/<로케일>/mac-0N-*.png    원본 2560×1600 (scripts/capture_mac_raw.sh)
  marketing/<로케일>/0N-*-ipad.png · 0N-*-mac.png   제출본, 원본과 같은 크기. DeployBar 가 크기로 기기를 가른다
"""
import pathlib, subprocess, sys, tempfile, time
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from make_marketing_screenshots import CAPTIONS, CHROME, RAW, OUT, html_lang

DEVICES = {
    # 캔버스, 글 크기(제목 · 보조), 그림 틀, 찍을 장(원본 이름, 문구 번호)
    "ipad": dict(W=2064, H=2752, head=128, sub=58, top=230,
                 frame="left:182px;top:860px;width:1700px", radius=64, pad=26,
                 shots=[("01-home", 0), ("02-conversation", 1), ("04-records", 3), ("05-friends", 4)]),
    "mac": dict(W=2560, H=1600, head=92, sub=44, top=96,
                frame="left:300px;top:400px;width:1960px", radius=22, pad=0,
                shots=[("01-home", 0), ("02-conversation", 1), ("04-records", 3), ("05-friends", 4)]),
}


def css(d):
    return f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{d['W']}px; height:{d['H']}px; overflow:hidden; }}
body {{ background:#FFF8EF; position:relative;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "Thonburi", sans-serif; }}
.glow {{ position:absolute; border-radius:50%; filter:blur(160px); background:rgba(244,213,141,.16); }}
.text {{ position:absolute; left:140px; right:140px; top:{d['top']}px; text-align:center; }}
.headline {{ font-weight:800; color:#4A3530; letter-spacing:-0.03em; line-height:1.14; text-wrap:balance; }}
.sub {{ font-weight:500; color:#6F584F; letter-spacing:-0.01em; line-height:1.32; margin-top:{d['sub']*0.6:.0f}px; text-wrap:balance; }}
:lang(th) .headline, :lang(ja) .headline, :lang(zh) .headline {{ letter-spacing:0; }}
:lang(th) .headline {{ line-height:1.32; }}
:lang(ko) .headline, :lang(ko) .sub {{ word-break:keep-all; }}
.frame {{ position:absolute; background:#17171a; border:3px solid #3a3a3e; padding:{d['pad']}px; border-radius:{d['radius'] + d['pad']}px;
  box-shadow: 50px 80px 120px rgba(35,44,43,.22), 16px 26px 44px rgba(35,44,43,.12); }}
.frame img {{ width:100%; display:block; border-radius:{d['radius']}px; }}
"""


def fit_js(d):
    return f"""
<script>
function lines(el){{ return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight)); }}
document.fonts.ready.then(() => {{
  const h = document.querySelector('.headline'), s = document.querySelector('.sub');
  const want = h.querySelectorAll('br').length + 1;
  let size = {d['head']}; h.style.fontSize = size + 'px';
  while (size > {d['head'] * 0.6:.0f} && (lines(h) > want || h.scrollWidth > h.clientWidth + 1)) {{ size -= 4; h.style.fontSize = size + 'px'; }}
  let sub = {d['sub']}; s.style.fontSize = sub + 'px';
  while (sub > {d['sub'] * 0.7:.0f} && lines(s) > 2) {{ sub -= 2; s.style.fontSize = sub + 'px'; }}
  if (lines(h) > want || lines(s) > 2) document.body.dataset.overflow = '1';
  document.body.dataset.done = '1';
}});
</script>
"""


def render(device, locale):
    d = DEVICES[device]
    captions = CAPTIONS[locale]
    out_dir = OUT / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, index in d["shots"]:
        src = RAW / locale / f"{device}-{name}.png"
        if not src.exists():
            raise SystemExit(f"원본 없음: {src}")
        headline, sub = captions[index]
        # 맥 · 아이패드는 가로로 넓다. 아이폰용 줄바꿈을 지워 한두 줄로 흐르게 한다.
        if device == "mac":
            headline = headline.replace("<br>", " ")
        body = (f'<div class="glow" style="left:-300px;top:500px;width:2400px;height:2000px"></div>'
                f'<div class="frame" style="{d["frame"]}"><img src="{src.as_uri()}"></div>'
                f'<div class="text"><div class="headline">{headline}</div><div class="sub">{sub}</div></div>')
        page = (f'<!doctype html><html lang="{html_lang(locale)}"><head><meta charset="utf-8">'
                f'<style>{css(d)}</style></head><body>{body}{fit_js(d)}</body></html>')
        html_path = pathlib.Path(tempfile.gettempdir()) / f"mochimo-{device}-{locale}-{name}.html"
        html_path.write_text(page, encoding="utf-8")
        common = ["--headless=new", f"--window-size={d['W']},{d['H']}", "--force-device-scale-factor=1",
                  "--hide-scrollbars", "--disable-gpu", "--virtual-time-budget=3000", "--allow-file-access-from-files"]
        dom = subprocess.run([CHROME, *common, "--dump-dom", html_path.as_uri()],
                             capture_output=True, text=True, timeout=300).stdout
        if 'data-done="1"' not in dom:
            raise SystemExit(f"글 맞추기가 끝나지 않았다: {device} {locale} {name}")
        if 'data-overflow="1"' in dom:
            raise SystemExit(f"글이 넘친다: {device} {locale} {name} - 문구를 줄일 것")
        out_png = out_dir / f"{name}-{device}.png"
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
        time.sleep(1)


if __name__ == "__main__":
    device, *locales = sys.argv[1:]
    for locale in locales or list(CAPTIONS):
        render(device, locale)
