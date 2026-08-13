const fs = require('fs');

const prdEntry = `4:{title:'标记 4 · 考试诊断',badge:'交互规范',badgeType:'interaction',\n     text:'考试诊断跟随孩子切换'}`;
const markBtn  = `<span class="prd-mark" onclick="openPrd(event,4)">4</span>`;

// ── fenxi.html ──────────────────────────────────────────────
{
  let c = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/fenxi.html', 'utf8');

  // 在 考试诊断 按钮结束标签 </button> 后插入标记
  const target = `<span class="material-icons" style="font-size:16px">add_a_photo</span>考试诊断\n    </button>`;
  if (!c.includes(target)) { console.error('fenxi: 考试诊断按钮未找到'); process.exit(1); }
  c = c.replace(target, target + '\n  ' + markBtn);

  // 在 prdData 最后一个 } 前追加新条目
  // 找到 prdData 块的 closing };
  const pdEnd = c.indexOf('};\nfunction openPrd');
  if (pdEnd < 0) { console.error('fenxi: prdData 结尾未找到'); process.exit(1); }
  c = c.slice(0, pdEnd) + ',\n  ' + prdEntry + '\n' + c.slice(pdEnd);

  fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/fenxi.html', c, 'utf8');
  console.log('fenxi.html done, length:', c.length);
}

// ── cuoti.html ──────────────────────────────────────────────
{
  let c = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/cuoti.html', 'utf8');

  // 考试诊断按钮（单行内联写法）
  const target = `<span class="material-icons" style="font-size:16px">add_a_photo</span>考试诊断</button>`;
  if (!c.includes(target)) { console.error('cuoti: 考试诊断按钮未找到'); process.exit(1); }
  c = c.replace(target, target + markBtn);

  const pdEnd = c.indexOf('};\nfunction openPrd');
  if (pdEnd < 0) { console.error('cuoti: prdData 结尾未找到'); process.exit(1); }
  c = c.slice(0, pdEnd) + ',\n  ' + prdEntry + '\n' + c.slice(pdEnd);

  fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/cuoti.html', c, 'utf8');
  console.log('cuoti.html done, length:', c.length);
}
