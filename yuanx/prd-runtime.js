(function () {
  const isServer = location.protocol === 'http:' || location.protocol === 'https:';
  const pageName = location.pathname.replace(/^.*\//, '').replace(/\.html$/, '') || 'index';

  let _curMark = null; // 当前打开 popover 的 .prd-mark 按钮

  /* ── 工具：根据 id 找页面上的 .prd-mark 按钮 ── */
  function findMark(id) {
    // 匹配 onclick 里含 openPrd(event,id) 或 openPrd(event, id)
    return document.querySelector('.prd-mark[onclick*="openPrd(event,' + id + ')"]') ||
           document.querySelector('.prd-mark[onclick*="openPrd(event, ' + id + ')"]');
  }

  /* ── 1. 读取已保存数据，覆盖页面内 prdData 默认值 ── */
  function applyData(saved) {
    if (!saved || typeof saved !== 'object') return;
    const entries = saved[pageName];
    if (!entries) return;
    if (typeof prdData === 'undefined') return;
    Object.keys(entries).forEach(function (id) {
      if (!prdData[id]) return;
      const val = entries[id];
      if (typeof val === 'string') {
        prdData[id].text = val;
      } else if (val && typeof val === 'object') {
        if (val.text      !== undefined) prdData[id].text      = val.text;
        if (val.title     !== undefined) prdData[id].title     = val.title;
        if (val.badge     !== undefined) prdData[id].badge     = val.badge;
        if (val.markLabel !== undefined) prdData[id].markLabel = val.markLabel;
      }
    });
    // DOM 就绪后把圆圈文字还原
    function restoreLabels() {
      if (typeof prdData === 'undefined') return;
      Object.keys(prdData).forEach(function (id) {
        const d = prdData[id];
        if (d.markLabel !== undefined) {
          const btn = findMark(id);
          if (btn) btn.textContent = d.markLabel;
        }
      });
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', restoreLabels);
    } else {
      restoreLabels();
    }
  }

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

  /* ── 2. 统一 openPrd：序号 / 标题 / 标签 / 正文均可编辑 ── */
  window.openPrd = function (e, id) {
    e.stopPropagation();
    if (typeof closePrd === 'function') closePrd();
    if (typeof prdData === 'undefined') return;
    const d = prdData[id];
    if (!d) return;

    _curMark = e.currentTarget;
    const rect = _curMark.getBoundingClientRect();

    // 当前显示的序号文字（已编辑过则用 markLabel，否则用按钮现有文字）
    const labelVal = d.markLabel !== undefined ? d.markLabel : (_curMark.textContent || String(id));

    const overlay = document.createElement('div');
    overlay.className = 'prd-overlay';
    overlay.onclick = function () { if (typeof closePrd === 'function') closePrd(); };
    document.body.appendChild(overlay);

    const pop = document.createElement('div');
    pop.className = 'prd-popover';
    pop.id = 'prdPop';

    const badgeType = d.badgeType || '';
    const badgeCls  = 'prd-pop-badge' + (badgeType ? ' ' + badgeType : '');

    pop.innerHTML =
      '<div class="prd-pop-head">' +
        '<div style="display:flex;align-items:center;gap:6px;margin-bottom:8px">' +
          // 序号输入（小圆圈样式）
          '<input id="prdLabel" value="' + labelVal.replace(/"/g, '&quot;') + '" ' +
            'style="width:26px;height:26px;border-radius:50%;background:#1565C0;color:#fff;' +
            'font-size:11px;font-weight:700;text-align:center;border:none;outline:none;' +
            'cursor:text;flex-shrink:0;font-family:inherit;padding:0">' +
          // 标题输入
          '<input id="prdTitle" value="' + (d.title || '').replace(/"/g, '&quot;') + '" ' +
            'style="flex:1;font-size:13px;font-weight:700;border:none;border-bottom:1px solid #e0e0e0;' +
            'outline:none;padding:3px 0;background:transparent;color:#1A1A1A;font-family:inherit">' +
        '</div>' +
        '<div>' +
          // 标签输入
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

    const arrow = document.createElement('div');
    arrow.className = 'prd-popover-arrow';
    pop.appendChild(arrow);
    document.body.appendChild(pop);

    const popW = 290, popH = 300;
    const appEl = document.getElementById('app');
    const appRect = appEl ? appEl.getBoundingClientRect() : { left: 0, right: window.innerWidth };
    let left = Math.min(rect.left - 10, appRect.right - popW - 8);
    left = Math.max(appRect.left + 8, left);
    const spaceBelow = window.innerHeight - rect.bottom - 12;
    let top, arrowTop;
    if (spaceBelow >= popH) {
      top = rect.bottom + 8; arrowTop = -6;
    } else {
      top = rect.top - popH - 8; arrowTop = popH - 6;
    }
    pop.style.left = left + 'px';
    pop.style.top  = top  + 'px';
    const arrowLeft = Math.min(Math.max(rect.left - left + 4, 10), popW - 22);
    arrow.style.left = arrowLeft + 'px';
    arrow.style.top  = arrowTop  + 'px';
  };

  /* ── 3. 统一 savePrd：保存序号 / 标题 / 标签 / 正文 ── */
  window.savePrd = function (id) {
    const ta   = document.getElementById('prdTa');
    const lIn  = document.getElementById('prdLabel');
    const tIn  = document.getElementById('prdTitle');
    const bIn  = document.getElementById('prdBadge');
    if (!ta || typeof prdData === 'undefined') return;

    prdData[id].text = ta.value;
    if (tIn) prdData[id].title     = tIn.value;
    if (bIn) prdData[id].badge     = bIn.value;
    if (lIn) prdData[id].markLabel = lIn.value;

    // 同步更新圆圈文字
    if (lIn && _curMark) _curMark.textContent = lIn.value;

    const entry = {
      markLabel : prdData[id].markLabel,
      title     : prdData[id].title,
      badge     : prdData[id].badge,
      text      : prdData[id].text
    };

    // localStorage 备份
    const all = JSON.parse(localStorage.getItem('prd_all') || '{}');
    if (!all[pageName]) all[pageName] = {};
    all[pageName][String(id)] = entry;
    localStorage.setItem('prd_all', JSON.stringify(all));

    // 写服务器
    if (isServer) {
      fetch('prd-save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ page: pageName, id: id, data: entry })
      }).catch(function () {});
    }

    _curMark = null;
    if (typeof closePrd === 'function') closePrd();
    if (typeof showToast === 'function') showToast('产品规则已保存');
  };
})();
