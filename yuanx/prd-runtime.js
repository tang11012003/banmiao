(function () {
  const isServer = location.protocol === 'http:' || location.protocol === 'https:';
  const pageName = location.pathname.replace(/^.*\//, '').replace(/\.html$/, '') || 'index';

  let _curMark = null;

  function findMark(id) {
    return document.querySelector('.prd-mark[onclick*="openPrd(event,' + id + ')"]') ||
           document.querySelector('.prd-mark[onclick*="openPrd(event, ' + id + ')"]');
  }

  /* ── 合并已保存的编辑到 prdData ── */
  function applyData(saved) {
    if (!saved || typeof saved !== 'object') return;
    var entries = saved[pageName];
    if (!entries) return;
    if (typeof prdData === 'undefined' || !window.prdData) return;
    Object.keys(entries).forEach(function (id) {
      if (!prdData[id]) return;
      var val = entries[id];
      if (typeof val === 'string') {
        prdData[id].text = val;
      } else if (val && typeof val === 'object') {
        if (val.text      !== undefined) prdData[id].text      = val.text;
        if (val.title     !== undefined) prdData[id].title     = val.title;
        if (val.badge     !== undefined) prdData[id].badge     = val.badge;
        if (val.markLabel !== undefined) prdData[id].markLabel = val.markLabel;
      }
    });
    restoreLabels();
  }

  function restoreLabels() {
    if (typeof prdData === 'undefined' || !window.prdData) return;
    Object.keys(prdData).forEach(function (id) {
      var d = prdData[id];
      if (d.markLabel !== undefined) {
        var btn = findMark(id);
        if (btn) btn.textContent = d.markLabel;
      }
    });
  }

  /* ── 初始化：加载默认值 → 合并用户编辑 ── */
  function init(defaults) {
    var pageDefaults = defaults[pageName];
    if (pageDefaults) {
      window.prdData = {};
      Object.keys(pageDefaults).forEach(function (id) {
        var d = pageDefaults[id];
        window.prdData[id] = {
          title: d.title || '',
          badge: d.badge || '',
          badgeType: d.badgeType || '',
          text: d.text || ''
        };
      });
    } else if (typeof window.prdData === 'undefined') {
      window.prdData = {};
    }

    // 合并用户保存的编辑
    if (isServer) {
      fetch('prd-data.json?_=' + Date.now())
        .then(function (r) { return r.ok ? r.json() : {}; })
        .then(applyData)
        .catch(function () {
          applyData(JSON.parse(localStorage.getItem('prd_all') || '{}'));
        });
    } else {
      applyData(JSON.parse(localStorage.getItem('prd_all') || '{}'));
    }
  }

  // 加载 prd-defaults.json
  if (isServer) {
    fetch('prd-defaults.json?_=' + Date.now())
      .then(function (r) { return r.ok ? r.json() : {}; })
      .then(init)
      .catch(function () { init({}); });
  } else {
    // file:// 协议无法 fetch，用 XHR 同步加载
    try {
      var xhr = new XMLHttpRequest();
      xhr.open('GET', 'prd-defaults.json', false);
      xhr.send();
      init(xhr.status === 200 ? JSON.parse(xhr.responseText) : {});
    } catch (e) {
      init({});
    }
  }

  /* ── openPrd ── */
  window.openPrd = function (e, id) {
    e.stopPropagation();
    if (typeof closePrd === 'function') closePrd();
    if (typeof prdData === 'undefined' || !window.prdData) return;
    var d = prdData[id];
    if (!d) return;

    _curMark = e.currentTarget;
    var rect = _curMark.getBoundingClientRect();
    var labelVal = d.markLabel !== undefined ? d.markLabel : (_curMark.textContent || String(id));

    var overlay = document.createElement('div');
    overlay.className = 'prd-overlay';
    overlay.onclick = function () { if (typeof closePrd === 'function') closePrd(); };
    document.body.appendChild(overlay);

    var pop = document.createElement('div');
    pop.className = 'prd-popover';
    pop.id = 'prdPop';

    var badgeType = d.badgeType || '';
    var badgeCls  = 'prd-pop-badge' + (badgeType ? ' ' + badgeType : '');

    pop.innerHTML =
      '<div class="prd-pop-head">' +
        '<div style="display:flex;align-items:center;gap:6px;margin-bottom:8px">' +
          '<input id="prdLabel" value="' + labelVal.replace(/"/g, '&quot;') + '" ' +
            'style="width:26px;height:26px;border-radius:50%;background:#1565C0;color:#fff;' +
            'font-size:11px;font-weight:700;text-align:center;border:none;outline:none;' +
            'cursor:text;flex-shrink:0;font-family:inherit;padding:0">' +
          '<input id="prdTitle" value="' + (d.title || '').replace(/"/g, '&quot;') + '" ' +
            'style="flex:1;font-size:13px;font-weight:700;border:none;border-bottom:1px solid #e0e0e0;' +
            'outline:none;padding:3px 0;background:transparent;color:#1A1A1A;font-family:inherit">' +
        '</div>' +
        '<div>' +
          '<input id="prdBadge" value="' + (d.badge || '').replace(/"/g, '&quot;') + '" ' +
            'class="' + badgeCls + '" ' +
            'style="width:auto;min-width:48px;max-width:120px;text-align:center;border:none;' +
            'outline:none;cursor:text;font-family:inherit;font-size:10px;font-weight:600;' +
            'border-radius:8px;padding:2px 7px">' +
        '</div>' +
      '</div>' +
      '<div class="prd-pop-body">' +
        '<textarea id="prdTa">' + (d.text || '') + '</textarea>' +
      '</div>' +
      '<div class="prd-pop-foot">' +
        '<button class="prd-btn-cancel" onclick="closePrd()">取消</button>' +
        '<button class="prd-btn-save" onclick="savePrd(' + id + ')">保存</button>' +
      '</div>';

    var arrow = document.createElement('div');
    arrow.className = 'prd-popover-arrow';
    pop.appendChild(arrow);
    document.body.appendChild(pop);

    var popW = 290, popH = 300;
    var appEl = document.getElementById('app');
    var appRect = appEl ? appEl.getBoundingClientRect() : { left: 0, right: window.innerWidth };
    var left = Math.min(rect.left - 10, appRect.right - popW - 8);
    left = Math.max(appRect.left + 8, left);
    var spaceBelow = window.innerHeight - rect.bottom - 12;
    var top, arrowTop;
    if (spaceBelow >= popH) {
      top = rect.bottom + 8; arrowTop = -6;
    } else {
      top = rect.top - popH - 8; arrowTop = popH - 6;
    }
    pop.style.left = left + 'px';
    pop.style.top  = top  + 'px';
    var arrowLeft = Math.min(Math.max(rect.left - left + 4, 10), popW - 22);
    arrow.style.left = arrowLeft + 'px';
    arrow.style.top  = arrowTop  + 'px';
  };

  /* ── closePrd ── */
  window.closePrd = function () {
    var overlay = document.querySelector('.prd-overlay');
    if (overlay) overlay.remove();
    var pop = document.getElementById('prdPop');
    if (pop) pop.remove();
    _curMark = null;
  };

  /* ── savePrd ── */
  window.savePrd = function (id) {
    var ta   = document.getElementById('prdTa');
    var lIn  = document.getElementById('prdLabel');
    var tIn  = document.getElementById('prdTitle');
    var bIn  = document.getElementById('prdBadge');
    if (!ta || typeof prdData === 'undefined') return;

    prdData[id].text = ta.value;
    if (tIn) prdData[id].title     = tIn.value;
    if (bIn) prdData[id].badge     = bIn.value;
    if (lIn) prdData[id].markLabel = lIn.value;

    if (lIn && _curMark) _curMark.textContent = lIn.value;

    var entry = {
      markLabel : prdData[id].markLabel,
      title     : prdData[id].title,
      badge     : prdData[id].badge,
      text      : prdData[id].text
    };

    var all = JSON.parse(localStorage.getItem('prd_all') || '{}');
    if (!all[pageName]) all[pageName] = {};
    all[pageName][String(id)] = entry;
    localStorage.setItem('prd_all', JSON.stringify(all));

    if (isServer) {
      fetch('prd-save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ page: pageName, id: id, data: entry })
      }).catch(function () {});
    }

    _curMark = null;
    closePrd();
    if (typeof showToast === 'function') showToast('产品规则已保存');
  };
})();
