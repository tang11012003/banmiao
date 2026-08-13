const http = require('http');
const fs   = require('fs');
const path = require('path');

const PORT     = process.argv[2] || 3000;
const ROOT     = __dirname;
const PRD_FILE = path.join(ROOT, 'prd-data.json');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css' : 'text/css',
  '.js'  : 'application/javascript',
  '.json': 'application/json',
  '.png' : 'image/png',
  '.jpg' : 'image/jpeg',
  '.svg' : 'image/svg+xml',
  '.ico' : 'image/x-icon',
};

http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

  // POST /prd-save  { page, id, text }
  if (req.method === 'POST' && req.url.replace(/^.*\//, '') === 'prd-save') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      try {
        const payload = JSON.parse(body);
        const { page, id } = payload;
        // \u65B0\u683C\u5F0F\u4F20 data \u5BF9\u8C61 {title,badge,text}\uFF1B\u65E7\u683C\u5F0F\u4F20 text \u5B57\u7B26\u4E32
        const value = payload.data !== undefined ? payload.data : payload.text;
        const all = fs.existsSync(PRD_FILE)
          ? JSON.parse(fs.readFileSync(PRD_FILE, 'utf8').replace(/^\uFEFF/, ''))
          : {};
        if (!all[page]) all[page] = {};
        all[page][String(id)] = value;
        fs.writeFileSync(PRD_FILE, JSON.stringify(all, null, 2), 'utf8');
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      } catch (e) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // Static files
  let rel = req.url.split('?')[0];
  if (rel === '/') rel = '/fenxi.html';
  const filePath = path.join(ROOT, rel);
  if (!filePath.startsWith(ROOT)) { res.writeHead(403); res.end(); return; }

  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });

}).listen(PORT, () => {
  console.log(`\n PRD 服务已启动：http://localhost:${PORT}`);
  console.log(`    规则保存路径：${PRD_FILE}`);
  console.log(`    换端口请运行：node prd-server.js <端口号>\n`);
});
