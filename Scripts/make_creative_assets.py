#!/usr/bin/env python3
"""App Store 크리에이티브 자산(제품 페이지 헤더 · 검색 결과) 생성: HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_creative_assets.py [언어 ...]     (없으면 전부)

자리
  docs/screenshots/creative/<스토어 로케일>/header.png   3840x1646  제품 페이지 맨 위
  docs/screenshots/creative/<스토어 로케일>/search.png   3840x2560  검색 결과 (없으면 스크린샷이 대신 보인다)

⚠️ 안전 영역 밖은 기기에 따라 잘린다. 글은 **반드시** 안전 영역 안에 둔다(배경 · 기기 그림은 넘쳐도 된다).
   수치는 Apple 공식 PSD 템플릿에서 잰 값이다(https://developer.apple.com/app-store/asset-best-practices/).
   아이폰에서 헤더는 가운데만 남고, 검색 결과는 약 385pt 폭으로 줄어 보인다. 그래서 글이 크다.

⚠️ 가격 · 할인 · 주소(URL) · 수상 · 다른 플랫폼 이름은 넣지 않는다(Apple 가이드).
"""
import subprocess, sys, pathlib, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots"  # ko/, en/ 에 1242x2688 화면이 있다
OUT = ROOT / "docs" / "screenshots" / "creative"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 앱 언어 코드 → App Store Connect 로케일 (make_marketing_screenshots.py 와 같다)
STORE = {"en": "en-US"}

# (가로, 세로, 안전 영역 left, top, right, bottom)
SPEC = {
    "header": (3840, 1646, (1097, 493, 2743, 1154)),
    "search": (3840, 2560, (836, 765, 3004, 1795)),
}

# 눈썹글 · 헤드라인 · 보조 문장은 검색 결과에 쓴다. 스크린샷 1장과 **같은 이야기**다
# (검색에서 본 말이 페이지에서도 이어져야 한다, docs/marketing/ASO_2026-10.md).
# 눈썹글은 그 나라 검색어다.
SEARCH = {
    "ko": ("실패 기록 일기", "조약돌이<br>먼저 말을 걸어요", "무엇에 닿았고 무엇이 막혔는지<br>대화하듯 남겨요"),
    "en": ("Failure journal", "A pebble that<br>asks first", "Talk through what worked<br>and what got stuck"),
    "en-GB": ("Failure journal", "A pebble that<br>asks first", "Talk through what worked<br>and what got stuck"),
    "zh-Hans": ("失败日记", "小石子<br>会先开口", "像聊天一样记下<br>走到了哪里、被什么卡住"),
    "zh-Hant": ("失敗日記", "小石子<br>會先開口", "像聊天一樣記下<br>走到了哪裡、被什麼卡住"),
    "ja": ("失敗 日記", "小石が<br>先に声をかける", "何にたどり着き、何が引っかかったか<br>会話のように残す"),
    "ru": ("дневник неудач", "Камешек<br>заговорит первым", "Записывайте, до чего дошли<br>и что остановило, как в беседе"),
    "es": ("diario de fallos", "Un guijarro<br>que habla primero", "Anota hasta dónde llegaste<br>y qué te frenó, charlando"),
    "de": ("Misserfolg Tagebuch", "Ein Kiesel,<br>der zuerst fragt", "Festhalten, was du erreicht hast<br>und was dich aufhielt"),
    "fr": ("journal intime", "Un galet qui<br>parle le premier", "Notez où vous en êtes arrivé<br>et ce qui a coincé, en parlant"),
    "it": ("diario fallimenti", "Un sassolino<br>che parla per primo", "Annota dove sei arrivato<br>e cosa ti ha frenato, parlando"),
    "pt-BR": ("diário de fracassos", "Uma pedrinha<br>que puxa a conversa", "Anote até onde chegou<br>e o que travou, conversando"),
    "th": ("ไดอารี่ความล้มเหลว", "ก้อนหินเล็กๆ<br>ที่ทักก่อน", "จดว่าไปถึงไหน ติดขัดตรงไหน<br>เหมือนได้คุยกัน"),
    "vi": ("nhật ký thất bại", "Viên đá nhỏ<br>luôn mở lời trước", "Ghi lại đã đi tới đâu, vướng gì<br>như một cuộc trò chuyện"),
    "cs": ("deník selhání", "Oblázek, který<br>promluví první", "Zapište, kam jste se dostali<br>a co vás zastavilo, jako v rozhovoru"),
    "da": ("dagbog nederlag", "En sten,<br>der taler først", "Skriv ned, hvor langt du nåede<br>og hvad der stod i vejen"),
    "el": ("ημερολόγιο αποτυχίας", "Ένα βότσαλο που<br>μιλά πρώτο", "Σημείωσε πού έφτασες και τι σε<br>εμπόδισε, σαν κουβέντα"),
    "fi": ("epäonnistumispäiväkirja", "Kivi, joka<br>puhuu ensin", "Kirjaa, mihin pääsit ja mikä<br>tuli vastaan, kuin keskustellen"),
    "id": ("jurnal kegagalan", "Kerikil yang<br>menyapa lebih dulu", "Catat sampai mana kamu melangkah<br>dan apa yang menghalangi"),
    "nb": ("dagbok nederlag", "En stein som<br>snakker først", "Skriv ned hvor langt du kom<br>og hva som sto i veien"),
}

# 헤더는 처음 온 사람에게 **한 가지 약속**만 한다(Apple: 단일한 생각, 빽빽하지 않게).
# 앱이 무엇을 해 주는지를 한 문장으로: 한 번 써 두면 그다음은 누르기만 한다.
# ⚠️ 기계번역하지 않는다. 각 언어에서 짧게 읽히는 말로 따로 쓴다. 높임은 그 언어 스크린샷과 맞춘다.
HEADER = {
    "ko": ("막힌 날을 돌아보는 기록", "헛디뎌도<br>개울에 빠진 건 아니에요"),
    "en": ("A gentle failure journal", "Missing a step doesn't<br>mean you fell in"),
    "en-GB": ("A gentle failure journal", "Missing a step doesn't<br>mean you fell in"),
    "zh-Hans": ("回顾受阻日子的温柔日记", "踏空一步<br>并不等于掉进了溪水里"),
    "zh-Hant": ("回顧受阻日子的溫柔日記", "踏空一步<br>並不等於掉進了溪水裡"),
    "ja": ("つまずいた日を振り返る、やさしい日記", "踏み外しても<br>川に落ちたわけじゃない"),
    "ru": ("Бережный дневник трудных дней", "Оступиться — не значит<br>упасть в ручей"),
    "es": ("Un diario amable para días difíciles", "Dar un mal paso<br>no es caer al arroyo"),
    "de": ("Ein sanftes Tagebuch für schwere Tage", "Ein Fehltritt heißt nicht,<br>dass du in den Bach fällst"),
    "fr": ("Un journal tout doux pour les jours difficiles", "Un faux pas, ce n’est pas<br>tomber dans le ruisseau"),
    "it": ("Un diario gentile per i giorni difficili", "Un passo falso non è<br>cadere nel ruscello"),
    "pt-BR": ("Um diário gentil para dias difíceis", "Um passo em falso<br>não é cair no riacho"),
    "th": ("ไดอารี่อ่อนโยนสำหรับวันที่ไม่ราบรื่น", "พลาดก้าวหนึ่ง<br>ไม่ได้แปลว่าตกลงลำธาร"),
    "vi": ("Nhật ký dịu dàng cho những ngày khó", "Vấp một bước<br>không phải ngã xuống suối"),
    "cs": ("Laskavý deník pro těžké dny", "Klopýtnutí neznamená<br>pád do potoka"),
    "da": ("En venlig dagbog til svære dage", "Et fejltrin er ikke<br>et fald i åen"),
    "el": ("Ένα απαλό ημερολόγιο για δύσκολες μέρες", "Ένα παραπάτημα δεν είναι<br>πτώση στο ρυάκι"),
    "fi": ("Lempeä päiväkirja vaikeisiin päiviin", "Harha-askel ei ole<br>putoamista puroon"),
    "id": ("Jurnal lembut untuk hari yang berat", "Salah melangkah bukan<br>berarti jatuh ke sungai"),
    "nb": ("En vennlig dagbok for tunge dager", "Et feilsteg er ikke<br>et fall i bekken"),
}

# ⚠️ 바탕 · 글자색은 기존 스크린샷(make_marketing_screenshots.py)과 같다. 다르면 페이지에서
#    헤더만 남의 앱처럼 보인다.
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:#EFF3F3; position:relative;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", "Thonburi", sans-serif; }
.glow { position:absolute; border-radius:50%%; filter:blur(160px); pointer-events:none; }
.text { position:absolute; display:flex; flex-direction:column; justify-content:center; }
.eyebrow { font-weight:700; color:#5F8F93; letter-spacing:-0.01em; line-height:1.15; }
.headline { font-weight:800; color:#232C2B; letter-spacing:-0.03em; line-height:1.12; text-wrap:balance; }
.sub { font-weight:500; color:#566564; letter-spacing:-0.01em; line-height:1.35; text-wrap:balance; }
:lang(th) .headline, :lang(th) .eyebrow, :lang(th) .sub,
:lang(ja) .headline, :lang(zh) .headline { letter-spacing:0; }
:lang(th) .headline { line-height:1.3; }
/* 한국어는 낱말 중간에서 끊지 않는다("키 / 보드"). */
:lang(ko) .headline, :lang(ko) .sub, :lang(ko) .eyebrow { word-break:keep-all; }
.phone { position:absolute; background:#17171a; border:6px solid #3a3a3e; padding:40px; border-radius:190px;
  box-shadow: 60px 90px 140px rgba(35,44,43,.22), 20px 30px 50px rgba(35,44,43,.12); }
.phone img { width:100%%; display:block; border-radius:152px; }
.pebble { position:absolute; background-repeat:no-repeat;
  -webkit-mask-image:radial-gradient(ellipse 50%% 50%% at center, #000 62%%, transparent 100%%); }
"""

# 글이 상자를 넘지 않을 때까지 줄인다. 잘리는 글은 없다 - 끝까지 안 맞으면 표시하고 멈춘다.
FIT_JS = """
<script>
// 문구에 적은 줄(<br>)보다 더 쪼개지면 "Rispondi / con un / tocco" 처럼 읽기가 끊긴다.
// 적은 줄 수를 지킬 때까지 줄인다.
function lines(el) {
  return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
}
function fit(box, el, max, min) {
  const want = el.querySelectorAll('br').length + 1;
  let size = max;
  el.style.fontSize = size + 'px';
  while (size > min && (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 ||
         lines(el) > want)) {
    size -= 4; el.style.fontSize = size + 'px';
  }
  if (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 || lines(el) > want)
    document.body.dataset.overflow = '1';
}
document.fonts.ready.then(() => {
  const box = document.querySelector('.text');
  const h = document.querySelector('.headline');
  fit(box, h, +h.dataset.max, +h.dataset.min);
  document.body.dataset.done = '1';
});
</script>
"""


def phone(img, left, top, width, rotate=0):
    return (f'<div class="phone" style="left:{left}px;top:{top}px;width:{width}px;'
            f'transform:rotate({rotate}deg)"><img src="{img}"></div>')


def pebble(lang, x, y, w, rot=0, opacity=1):
    """첫 화면(01-greeting)의 조약돌을 오려 징검다리처럼 놓는다. 바탕색이 화면과 같아 경계가 보이지 않는다.
    안전 영역 밖 장식이다."""
    cx, cy, cw, ch = 380, 340, 490, 400          # 1242x2688 화면에서 조약돌 자리
    k = w / cw
    img = (RAW / lang / "01-greeting.png").as_uri()
    return (f'<div class="pebble" style="left:{x}px;top:{y}px;width:{w}px;height:{ch * k:.0f}px;'
            f'background-image:url({img});background-size:{1242 * k:.0f}px auto;'
            f'background-position:{-cx * k:.0f}px {-cy * k:.0f}px;transform:rotate({rot}deg);opacity:{opacity}"></div>')


def search_html(lang):
    W, H, (l, t, r, b) = SPEC["search"]
    eyebrow, headline, sub = SEARCH[lang]
    sw, sh = r - l, b - t
    col = int(sw * 0.56)
    ph_w = 1040
    ph_left = l + col + int(sw * 0.04)
    img = (RAW / lang / "01-greeting.png").as_uri()
    return f"""
<div class="glow" style="left:{ph_left - 300}px;top:500px;width:1700px;height:1700px;background:rgba(95,143,147,.10)"></div>
{phone(img, ph_left, t - 360, ph_w, 0)}
<div class="text" style="left:{l}px;top:{t}px;width:{col}px;height:{sh}px">
  <div class="eyebrow" style="font-size:96px">{eyebrow}</div>
  <div class="headline" data-max="250" data-min="140" style="margin-top:36px">{headline}</div>
  <div class="sub" style="font-size:84px;margin-top:52px">{sub}</div>
</div>"""


def header_html(lang):
    W, H, (l, t, r, b) = SPEC["header"]
    eyebrow, headline = HEADER[lang]
    sw, sh = r - l, b - t
    left_img = (RAW / lang / "01-greeting.png").as_uri()
    right_img = (RAW / lang / "04-stone-bridge.png").as_uri()
    # 글 아래로 조약돌이 징검다리처럼 건너간다(왼쪽 폰 → 오른쪽 폰).
    stones = [(1080, 1240, 300, -6), (1520, 1300, 260, 4), (1920, 1250, 280, -3), (2330, 1300, 250, 7)]
    stones_html = "".join(pebble(lang, x, y, w, rot) for x, y, w, rot in stones)
    return f"""
<div class="glow" style="left:{l - 200}px;top:{t - 400}px;width:{sw + 400}px;height:{sh + 800}px;background:rgba(95,143,147,.07)"></div>
{stones_html}
{phone(left_img, 300, 360, 640, -9)}
{phone(right_img, 2900, 360, 640, 9)}
<div class="text" style="left:{l}px;top:{t}px;width:{sw}px;height:{sh}px;align-items:center;text-align:center">
  <div class="eyebrow" style="font-size:76px">{eyebrow}</div>
  <div class="headline" data-max="210" data-min="110" style="margin-top:22px">{headline}</div>
</div>"""


def html_lang(lang):
    return {"zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant"}.get(lang, lang)


def render(lang, kind):
    W, H, _ = SPEC[kind]
    body = search_html(lang) if kind == "search" else header_html(lang)
    page = (f'<!doctype html><html lang="{html_lang(lang)}"><head><meta charset="utf-8"><style>'
            f'{BASE_CSS % {"W": W, "H": H}}</style></head><body>{body}{FIT_JS}</body></html>')
    html_path = pathlib.Path(tempfile.gettempdir()) / f"zinggumdol-creative-{lang}-{kind}.html"
    html_path.write_text(page, encoding="utf-8")
    # 글이 끝까지 안 맞으면 그림을 만들지 않는다(잘린 글이 스토어에 올라가는 것보다 낫다).
    dom = subprocess.run([CHROME, "--headless=new", "--dump-dom", f"--window-size={W},{H}",
                          "--force-device-scale-factor=1", "--disable-gpu", "--virtual-time-budget=3000",
                          html_path.as_uri()], capture_output=True, text=True, timeout=400).stdout
    if 'data-done="1"' not in dom:
        raise SystemExit(f"글 맞추기가 끝나지 않았다: {lang} {kind}")
    if 'data-overflow="1"' in dom:
        raise SystemExit(f"글이 안전 영역을 넘는다: {lang} {kind} - 문구를 줄일 것")
    out_dir = OUT / STORE.get(lang, lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_png = out_dir / f"{kind}.png"
    # ⚠️ Chrome 은 가끔 아무것도 안 그리고 끝나거나 멈춘다. 세 번까지 한다.
    for _ in range(3):
        try:
            r = subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}",
                                f"--window-size={W},{H}", "--force-device-scale-factor=1",
                                "--hide-scrollbars", "--disable-gpu", "--virtual-time-budget=3000",
                                "--allow-file-access-from-files", html_path.as_uri()],
                               capture_output=True, timeout=400)
        except subprocess.TimeoutExpired:
            continue
        if r.returncode == 0:
            break
    else:
        raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
    print(f"rendered {out_png}")


if __name__ == "__main__":
    langs = sys.argv[1:] or list(SEARCH)
    for lang in langs:
        if lang not in SEARCH:
            raise SystemExit(f"모르는 언어: {lang} (아는 것: {', '.join(SEARCH)})")
        for kind in ("header", "search"):
            render(lang, kind)
