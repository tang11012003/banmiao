const fs = require('fs');

// ── shequ.html ──────────────────────────────────────────────
let s = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/shequ.html', 'utf8');

// 1. 移除 circle CSS
s = s.replace(/\.circle-strip\{[^}]+\}\s*/g, '');
s = s.replace(/\.circle-strip::[\w-]+\{[^}]+\}\s*/g, '');
s = s.replace(/\.circle-chip\{[^}]+\}\s*/g, '');
s = s.replace(/\.circle-chip\.active\{[^}]+\}\s*/g, '');
s = s.replace(/\.circle-chip:not\(\.active\)\{[^}]+\}\s*/g, '');

// 2. 移除 circle-strip HTML div（含 prd-mark）
// 形如 <div class="circle-strip" id="circleStrip"></div>
s = s.replace(/<div[^>]*class="circle-strip"[^>]*><\/div>\s*/g, '');

// 3. 移除 circles 数组和 activeCircle 变量
s = s.replace(/const circles=\[\s*[\s\S]*?\];\s*\n/m, '');
s = s.replace(/let activeCircle=\d+;\s*\n/m, '');

// 4. 移除 renderCircles() 函数
s = s.replace(/function renderCircles\(\)\{[\s\S]*?\n\}\s*\n/m, '');

// 5. 移除 filterCircle() 函数
s = s.replace(/function filterCircle\(id\)\{[\s\S]*?\n\}\s*\n/m, '');

// 6. 简化 renderPosts() — 去掉过滤逻辑，直接用 mockPosts
s = s.replace(
  /const filtered=activeCircle===0\?mockPosts:mockPosts\.filter\(p=>p\.circleId===activeCircle\);/,
  'const filtered=mockPosts;'
);

// 7. 移除初始化调用 renderCircles()
s = s.replace(/renderCircles\(\);\s*\n/g, '');

fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/shequ.html', s, 'utf8');
console.log('shequ.html done, length:', s.length);

// ── fabutiezi.html ──────────────────────────────────────────
let f = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/fabutiezi.html', 'utf8');

// 移除 选择圈子 input-group 块
f = f.replace(
  /\s*<div class="input-group">\s*<label>选择圈子<\/label>[\s\S]*?<\/select>\s*<\/div>\s*/m,
  '\n  '
);

fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/fabutiezi.html', f, 'utf8');
console.log('fabutiezi.html done, length:', f.length);
