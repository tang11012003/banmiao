const fs = require('fs');

// 从各 HTML 文件提取 prdData 默认值，写回 prd-data.json
const dir = 'C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/';
const prdFile = dir + 'prd-data.json';

// 要恢复的页面和对应文件
const pages = {
  wode:             'wode.html',
  xiaoxi:           'xiaoxi.html',
  fenxi:            'fenxi.html',
  login:            'login.html',
  shangchuanfupan:  'shangchuanfupan.html',
  gouxuancuoti:     'gouxuancuoti.html',
};

const prdAll = JSON.parse(fs.readFileSync(prdFile, 'utf8'));

for (const [page, file] of Object.entries(pages)) {
  const html = fs.readFileSync(dir + file, 'utf8');

  // 找 prdData = { ... } 块
  const m = html.match(/const prdData\s*=\s*(\{[\s\S]*?\});\s*\n/);
  if (!m) { console.log('跳过（未找到 prdData）:', page); continue; }

  let obj;
  try {
    // 把单引号转双引号以便 JSON.parse（简单处理原型用的对象字面量）
    // 用 eval 在 Node 里安全执行（本地文件，可控）
    obj = eval('(' + m[1] + ')');
  } catch(e) {
    console.log('解析失败:', page, e.message);
    continue;
  }

  const existing = prdAll[page] || {};
  // 只写入 existing 里没有的 key（不覆盖已有数据）
  let added = 0;
  for (const id of Object.keys(obj)) {
    if (!existing[id]) {
      existing[id] = { title: obj[id].title, badge: obj[id].badge, text: obj[id].text };
      added++;
    }
  }
  prdAll[page] = existing;
  console.log(`${page}: 补充 ${added} 条`);
}

fs.writeFileSync(prdFile, JSON.stringify(prdAll, null, 2), 'utf8');
console.log('完成');
