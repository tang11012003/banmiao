/**
 * 运行方式：在 localhost:3000 的任意页面，打开 DevTools Console 粘贴执行。
 * 会打印出 localStorage 里存的所有 PRD 数据，并尝试恢复到 prd-data.json。
 */
(async function recover() {
  const local = JSON.parse(localStorage.getItem('prd_all') || '{}');
  console.log('=== localStorage prd_all ===');
  console.log(JSON.stringify(local, null, 2));

  // 尝试 POST 恢复每条数据
  let ok = 0, fail = 0;
  for (const page of Object.keys(local)) {
    for (const id of Object.keys(local[page])) {
      const val = local[page][id];
      const entry = typeof val === 'string'
        ? { text: val }
        : val;
      try {
        const r = await fetch('/prd-save', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ page, id, data: entry })
        });
        if (r.ok) { ok++; console.log('恢复', page, id); }
        else { fail++; console.warn('失败', page, id, r.status); }
      } catch(e) { fail++; console.warn('失败', page, id, e); }
    }
  }
  console.log(`完成：成功 ${ok} 条，失败 ${fail} 条`);
})();
