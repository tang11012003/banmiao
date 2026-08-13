const fs = require('fs');
let c = fs.readFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/login.html', 'utf8');

// 1. Remove Step 4 CSS block
c = c.replace(/\n\/\* Step 4: Parent Certification \*\/[\s\S]*?(?=\n\/\* Toast \*\/)/, '');

// 2. Remove Step 4 HTML block
c = c.replace(/\n\n<!-- Step 4: Certification -->\n<div class="step" id="step4">[\s\S]*?<\/div>\n<\/div>\n<\/div>/, '');

// 3. Change saveChildAndGoStep4 to navigate directly to fenxi.html
const oldSave = `  localStorage.setItem('child_info', JSON.stringify(childInfo));
  showToast('孩子档案保存成功');

  setTimeout(()=>{
    goToStep(4);
    renderStep4();
  }, 600);
}`;
const newSave = `  localStorage.setItem('child_info', JSON.stringify(childInfo));
  showToast('孩子档案保存成功');
  setTimeout(()=>{window.location.href='fenxi.html'},600);
}`;
c = c.replace(oldSave, newSave);

// 4. Remove Step 4 JS block
c = c.replace(/\n\/\/ Step 4: Certification\nlet certMethod[\s\S]*?(?=\nconst prdData)/, '');

// 5. Remove prdData entry 4
c = c.replace(/,\n  4:\{title:'标记 4[\s\S]*?'\}/, '');

// 6. Update prdData entry 2 text
c = c.replace(
  '• 888888 触发新用户建档流程（Step 2 -> Step 3 -> Step 4）',
  '• 888888 触发新用户建档流程（Step 2 -> Step 3）'
);

fs.writeFileSync('C:/Users/30433/Desktop/陪伴/peidu-community/yuanx/login.html', c, 'utf8');
console.log('done, length:', c.length);
