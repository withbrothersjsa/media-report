/*
 * weeknav.js — 리포트 페이지 상단 '주차 이동 바'
 *  - archive.json(루트, 아카이브생성.py 산출물)을 읽어 ◀ 이전 / 주차 선택 ▾ / 다음 ▶ 바를 그린다.
 *  - 루트 index.html 과 리포트/*.html 양쪽에서 동작 (경로 자동 판별).
 *  - archive.json 을 못 읽으면(로컬 file:// 등) 아무것도 그리지 않는다.
 */
(function () {
  var path = decodeURIComponent(location.pathname);
  var base = path.indexOf("/리포트/") >= 0 ? "../" : "./";

  fetch(base + "archive.json")
    .then(function (r) { if (!r.ok) throw 0; return r.json(); })
    .then(function (data) {
      var reports = data.reports || [];
      if (!reports.length) return;

      // 현재 페이지가 몇 번째 주차인지 판별 (index.html·루트는 최신 = 0)
      var cur = 0;
      var fname = path.split("/").pop();
      for (var i = 0; i < reports.length; i++) {
        if (reports[i].file.split("/").pop() === fname) { cur = i; break; }
      }

      var css =
        "#weeknav{position:sticky;top:0;z-index:50;display:flex;align-items:center;gap:10px;" +
        "padding:9px 20px;background:#101024;border-bottom:1px solid rgba(255,255,255,.08);" +
        "font-family:inherit;}" +
        "#weeknav .wn-label{font-size:12px;font-weight:700;letter-spacing:.08em;color:rgba(255,255,255,.45);" +
        "text-transform:uppercase;margin-right:auto;}" +
        "#weeknav button{min-width:34px;height:30px;border:1px solid rgba(255,255,255,.22);border-radius:8px;" +
        "background:transparent;color:#fff;font-size:13px;cursor:pointer;transition:border-color .15s,background .15s;}" +
        "#weeknav button:hover{border-color:#8f8fe8;background:rgba(143,143,232,.12);}" +
        "#weeknav button:disabled{opacity:.3;cursor:default;border-color:rgba(255,255,255,.22);background:transparent;}" +
        "#weeknav select{height:30px;border:1px solid rgba(255,255,255,.22);border-radius:8px;background:#1b1b38;" +
        "color:#fff;font-size:13px;font-weight:600;padding:0 8px;cursor:pointer;outline:none;}" +
        "@media(max-width:680px){#weeknav{padding:8px 12px;}#weeknav .wn-label{display:none;}}";
      var style = document.createElement("style");
      style.textContent = css;
      document.head.appendChild(style);

      function go(idx) {
        if (idx < 0 || idx >= reports.length) return;
        location.href = base + encodeURI(reports[idx].file);
      }

      var bar = document.createElement("div");
      bar.id = "weeknav";

      var label = document.createElement("span");
      label.className = "wn-label";
      label.textContent = "주간 리포트 아카이브";

      var prev = document.createElement("button");
      prev.textContent = "◀";
      prev.title = "이전 주차";
      prev.disabled = cur >= reports.length - 1;
      prev.onclick = function () { go(cur + 1); };

      var sel = document.createElement("select");
      reports.forEach(function (r, i) {
        var o = document.createElement("option");
        o.value = i;
        o.textContent = r.label + (i === 0 ? " (최신)" : "");
        if (i === cur) o.selected = true;
        sel.appendChild(o);
      });
      sel.onchange = function () { go(parseInt(sel.value, 10)); };

      var next = document.createElement("button");
      next.textContent = "▶";
      next.title = "다음 주차";
      next.disabled = cur <= 0;
      next.onclick = function () { go(cur - 1); };

      bar.appendChild(label);
      bar.appendChild(prev);
      bar.appendChild(sel);
      bar.appendChild(next);
      document.body.insertBefore(bar, document.body.firstChild);
    })
    .catch(function () { /* archive.json 없음/차단 — 바를 그리지 않는다 */ });
})();
