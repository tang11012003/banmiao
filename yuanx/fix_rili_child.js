const fs = require('fs');
let c = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/rili.html', 'utf8');

// 1. 在 mockEvents 定义前插入 childList
const anchor = 'const mockEvents=[';
if (!c.includes('const childList')) {
  c = c.replace(anchor, `const childList=[{id:'1',name:'张小明'},{id:'2',name:'张小红'}];\n${anchor}`);
}

// 构造 select HTML（内联样式与其他字段保持一致）
const childSelectHtml = `<div style="margin-bottom:14px"><label style="display:block;font-size:13px;color:#424242;margin-bottom:6px">关联孩子（可选）</label><select id="evChild" style="width:100%;padding:10px 12px;border:1px solid #e0e0e0;border-radius:8px;font-size:14px;outline:none;background:#fff"><option value=""></option>\${childList.map(ch=>\`<option value="\${ch.id}">\${ch.name}</option>\`).join('')}</select></div>`;

// 2a. preDate 弹窗：在备注字段前插入（备注字段 id=evSubject，preDate 分支）
// 定位特征：preDate 分支的备注 label
const preNoteLabel = `<div style="margin-bottom:20px"><label style="display:block;font-size:13px;color:#424242;margin-bottom:6px">备注（可填）</label><input id="evSubject" style="width:100%;padding:10px 12px;border:1px solid #e0e0e0;border-radius:8px;font-size:14px;outline:none" placeholder="请输入..."></div>`;
const preNoteNew   = childSelectHtml + '\n  ' + preNoteLabel;
if (c.includes(preNoteLabel)) {
  c = c.replace(preNoteLabel, preNoteNew);
} else {
  console.error('preDate 备注字段未找到'); process.exit(1);
}

// 2b. 全局新建弹窗：备注字段样式略有不同（margin-bottom:16px）
const fullNoteLabel = `<div style="margin-bottom:16px"><label style="display:block;font-size:13px;color:#424242;margin-bottom:4px">备注（可填）</label><input id="evSubject" style="width:100%;padding:10px 12px;border:1px solid #e0e0e0;border-radius:8px;font-size:14px;outline:none" placeholder="请输入..."></div>`;
const fullNoteNew   = childSelectHtml + '\n  ' + fullNoteLabel;
if (c.includes(fullNoteLabel)) {
  c = c.replace(fullNoteLabel, fullNoteNew);
} else {
  console.error('全局弹窗备注字段未找到'); process.exit(1);
}

// 3. saveEvent：读取 evChild 并存入 mockEvents
const oldSave = `mockEvents.push({title,date:modalPickerDate,type:'custom',subject:subject||''});`;
const newSave = `const child=document.getElementById('evChild').value;\nmockEvents.push({title,date:modalPickerDate,type:'custom',subject:subject||'',child:child||''});`;
if (c.includes(oldSave)) {
  c = c.replace(oldSave, newSave);
} else {
  console.error('saveEvent push 语句未找到'); process.exit(1);
}

fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/rili.html', c, 'utf8');
console.log('done, length:', c.length);
