const fs = require('fs');
let c = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/rili.html', 'utf8');

// 1. 替换日程卡片模板字符串
const oldCard = `<div class="card">
<div class="section-title">\${selLabel} 日程 · 共 \${dayEvents.length} 件</div><span class="prd-mark" onclick="openPrd(event,2)">2</span>
\${dayEvents.length===0?\`<div style="font-size:13px;color:var(--hint);text-align:center;padding:12px 0">当天暂无日程</div><div style="text-align:center;padding:4px 0 8px"><button onclick="addEvent('','\${selectedDate.getFullYear()}-\${String(selectedDate.getMonth()+1).padStart(2,'0')}-\${String(selectedDate.getDate()).padStart(2,'0')}')" style="display:inline-flex;align-items:center;gap:4px;padding:8px 20px;border-radius:20px;border:1.5px dashed var(--primary);background:none;color:var(--primary);font-size:14px;font-weight:500;cursor:pointer"><span class="material-icons" style="font-size:16px">add</span>添加日程</button></div><span class="prd-mark" onclick="openPrd(event,3)">3</span>\`:dayEvents.map(ev=>{const idx=mockEvents.indexOf(ev);return\`<div class="event-item" onclick="showEventDetail(\${idx})"><span class="material-icons" style="color:\${typeColors[ev.type]||'var(--hint)'}">\${ev.type==='mock_exam'?'assignment':ev.type==='gaokao'?'flag':ev.type==='physical_exam'?'local_hospital':'event'}</span><div class="ev-content"><div class="ev-title">\${ev.title}</div><div class="ev-sub">\${ev.date}\${ev.subject?' · '+ev.subject:''}</div></div><span class="material-icons" style="font-size:18px;color:var(--hint)">chevron_right</span></div>\`}).join('')}
</div>`;

const newCard = `<div class="card">
<div class="section-title">
  <span>\${selLabel} 日程 · 共 \${dayEvents.length} 件</span><span class="prd-mark" onclick="openPrd(event,2)" style="margin-left:6px">2</span>
  \${dayEvents.length>0?\`<button class="add-sub-btn" onclick="addEvent('','\${curSelFormatted}')"><span class="material-icons">add</span>添加</button>\`:''}
</div>
\${dayEvents.length===0?\`<div style="font-size:13px;color:var(--hint);text-align:center;padding:12px 0">当天暂无日程</div><div style="text-align:center;padding:4px 0 8px"><button onclick="addEvent('','\${curSelFormatted}')" style="display:inline-flex;align-items:center;gap:4px;padding:8px 20px;border-radius:20px;border:1.5px dashed var(--primary);background:none;color:var(--primary);font-size:14px;font-weight:500;cursor:pointer"><span class="material-icons" style="font-size:16px">add</span>添加日程</button></div><span class="prd-mark" onclick="openPrd(event,3)">3</span>\`:dayEvents.map(ev=>{const idx=mockEvents.indexOf(ev);return\`<div class="event-item" onclick="showEventDetail(\${idx})"><span class="material-icons" style="color:\${typeColors[ev.type]||'var(--hint)'}">\${ev.type==='mock_exam'?'assignment':ev.type==='gaokao'?'flag':ev.type==='physical_exam'?'local_hospital':'event'}</span><div class="ev-content"><div class="ev-title">\${ev.title}</div><div class="ev-sub">\${ev.date}\${ev.subject?' · '+ev.subject:''}</div></div><span class="material-icons" style="font-size:18px;color:var(--hint)">chevron_right</span></div>\`}).join('')}
</div>`;

if (!c.includes(oldCard)) {
  console.error('目标字符串未找到，请检查');
  process.exit(1);
}
c = c.replace(oldCard, newCard);

// 2. 在 render() 函数开头添加 curSelFormatted 变量（在 dayEvents 赋值后）
const oldRenderHead = `function render(){
const dayEvents=getEventsForDate(selectedDate);`;
const newRenderHead = `function render(){
const dayEvents=getEventsForDate(selectedDate);
const curSelFormatted=\`\${selectedDate.getFullYear()}-\${String(selectedDate.getMonth()+1).padStart(2,'0')}-\${String(selectedDate.getDate()).padStart(2,'0')}\`;`;
c = c.replace(oldRenderHead, newRenderHead);

// 3. 添加 .add-sub-btn CSS（在 </style> 前）
const addBtnCss = `
.section-title{display:flex;align-items:center}
.add-sub-btn{margin-left:auto;display:inline-flex;align-items:center;gap:2px;padding:4px 10px;border-radius:14px;border:1px solid var(--primary);background:none;color:var(--primary);font-size:12px;font-weight:500;cursor:pointer;line-height:1}
.add-sub-btn .material-icons{font-size:14px}
.add-sub-btn:active{background:rgba(230,67,26,.07)}
`;

// 检查 .section-title 是否已有 display:flex，避免重复
if (c.includes('.add-sub-btn')) {
  console.log('CSS 已存在，跳过');
} else {
  c = c.replace('</style>', addBtnCss + '</style>');
}

fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/rili.html', c, 'utf8');
console.log('done, length:', c.length);
