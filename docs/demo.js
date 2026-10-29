// 징검돌 웹 체험: 목표를 놓친 날 조약돌과 나누는 대화를 앱과 같은 순서로 해 본다.
// 순서는 ConversationEngine 과 같다: 관찰 → 확인 → 있었던 일 → 마음 → 되짚기 → (마음이 바닥이면 쉬기) 작은 한 걸음 → 마무리.
// 문장은 앱의 Localizable.xcstrings, 예시 기록은 ScreenshotMode 의 샘플에서 가져왔다. 지난 기록이 없는 첫 대화라 '예전에 해낸 일' 마디는 없다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const ko = document.documentElement.lang === "ko";
  const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const esc = s => s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

  // %@ · %1$@ 자리 채우기 (xcstrings 형식)
  const fmt = (tpl, ...a) => { let i = 0; return tpl.replace(/%(?:(\d)\$)?@/g, (_, n) => a[n ? n - 1 : i++] ?? ""); };
  // 받침에 따라 조사 고르기 (String.particle). 한국어가 아니면 붙이지 않는다.
  const particle = (w, withFinal, without) => {
    if (!ko) return "";
    const c = w.charCodeAt(w.length - 1) - 0xAC00;
    return c >= 0 && c < 11172 && c % 28 ? withFinal : without;
  };
  const condensed = s => s.length > 28 ? s.slice(0, 28).trim() + "…" : s;   // 되짚을 때 앞부분만

  root.innerHTML = `
    <div class="zg-stage">
      <div class="zg-top">
        <div class="zg-stages" aria-hidden="true"><i></i><i></i><i></i><span></span></div>
        <button type="button" class="zg-stop">${esc(T.stop)}</button>
      </div>
      <div class="zg-pebble" aria-hidden="true"><b></b></div>
      <ol class="zg-log" aria-live="polite"></ol>
    </div>
    <div class="zg-side">
      <div class="zg-reply"></div>
      <p class="muted small">${esc(T.note)}</p>
    </div>`;
  const $ = s => root.querySelector(s);
  const log = $(".zg-log"), reply = $(".zg-reply"), pebble = $(".zg-pebble"), stopBtn = $(".zg-stop");

  let s, live = false;   // 대화 상태 · 사용자가 손을 댔는지 (그 전에는 초점을 옮기지 않는다)
  root.addEventListener("pointerdown", () => { live = true; });
  root.addEventListener("keydown", () => { live = true; });
  const focus = el => { if (live && el) el.focus({ preventScroll: true }); };
  const line = (who, text) => {
    const li = document.createElement("li");
    li.className = `zg-m-${who}`;
    li.textContent = text;
    log.append(li);
    log.scrollTop = log.scrollHeight;
    if (who === "pebble" && !calm) { pebble.classList.remove("talk"); void pebble.offsetWidth; pebble.classList.add("talk"); }
  };
  const stage = n => {
    [...root.querySelectorAll(".zg-stages i")].forEach((d, i) => d.classList.toggle("on", i === n));
    $(".zg-stages span").textContent = T.stages[n];
  };
  // 조약돌이 말하고 나서 답할 거리를 내놓는다 (앱은 글자가 찍힌 뒤에 답을 받는다)
  const say = (text, then) => { reply.innerHTML = ""; line("pebble", text); setTimeout(then, calm ? 0 : 450); };

  const choices = list => {
    reply.innerHTML = list.map(([label], i) => `<button type="button" class="zg-choice" data-i="${i}">${esc(label)}</button>`).join("");
    reply.onclick = e => { const b = e.target.closest("[data-i]"); if (b) { line("user", list[b.dataset.i][0]); list[b.dataset.i][1](); } };
    focus(reply.querySelector("button"));
  };
  const freeform = (ph, sample, done) => {
    reply.innerHTML = `<form class="zg-form"><textarea rows="3" placeholder="${esc(ph)}" aria-label="${esc(ph)}">${esc(sample)}</textarea>
      <button type="submit" class="zg-send">${esc(T.send)}</button></form>`;
    const f = reply.querySelector("form"), ta = f.querySelector("textarea");
    reply.onclick = null;
    f.onsubmit = e => { e.preventDefault(); const t = ta.value.trim(); if (!t) return ta.focus(); line("user", t); done(t); };
    ta.onkeydown = e => { if (e.key === "Enter" && !e.shiftKey && !e.isComposing) { e.preventDefault(); f.requestSubmit(); } };
    focus(ta);
  };
  const ack = (label, next) => choices([[label, next]]);

  function start() {
    s = { reached: false, facts: "", feel: null, next: "" };
    log.innerHTML = ""; stopBtn.hidden = false; stage(0);
    say(fmt(T.obs, T.goal), () => choices([[T.yes, askFacts], [T.actually, askWorked], [T.leave, () => finish(T.leaveClose)]]));
  }
  const askFacts = () => say(fmt(T.facts, T.goal), () => freeform(T.factsPh, T.factsSample, t => { s.facts = t; askEmotion(); }));
  const askWorked = () => { s.reached = true;
    say(T.worked, () => freeform(T.workedPh, T.workedSample, t => { s.facts = t; askEmotion(); })); };
  function askEmotion() {
    stage(1);
    say(T.emotion, () => {
      reply.innerHTML = `<div class="zg-scale">${T.steps.map((l, v) => `<button type="button" class="zg-choice" data-v="${v}">${esc(l)}</button>`).join("")}</div>`;
      reply.onclick = e => {
        const b = e.target.closest("[data-v]"); if (!b) return;
        s.feel = +b.dataset.v; line("user", T.steps[s.feel]);
        if (s.reached) return finish(T.reachedClose);
        const w = T.steps[s.feel];
        say(fmt(T.sepTpl, T.sepOpen, condensed(s.facts), w, particle(w, "이에요", "예요"), T.sepClose), () => ack(T.ack, smallerOrClose));
      };
      focus(reply.querySelector("button"));
    });
  }
  // 마음이 바닥(1 이하)이면 쪼개기 질문을 건너뛰고 쉬자고 한다 (tooLowToAnalyze)
  function smallerOrClose() {
    if (s.feel <= 1) return finish(T.gentleClose);
    stage(2);
    say(T.smaller, () => freeform(T.smallerPh, T.nextSample, t => { s.next = t; finish(T.analyticClose); }));
  }
  function finish(text) {
    stopBtn.hidden = true;
    say(text, () => ack(T.finish, summary));
  }
  // 대화가 끝나면 남는 것: 말한 칸만
  function summary() {
    const rows = [[T.stages[0], s.facts], [T.stages[1], s.feel == null ? "" : T.steps[s.feel]], [T.stages[2], s.next]].filter(r => r[1]);
    reply.innerHTML = (rows.length ? `<dl class="zg-record">${rows.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${esc(v)}</dd></div>`).join("")}</dl>` : "")
      + `<button type="button" class="zg-again">${esc(T.again)}</button>`;
    reply.onclick = e => { if (e.target.closest(".zg-again")) start(); };
    focus(reply.querySelector(".zg-again"));
  }
  stopBtn.onclick = () => { live = true; finish(T.leaveClose); };   // 앱의 leave(): 말없이 짧게 인사하고 끝낸다

  start();
})();
