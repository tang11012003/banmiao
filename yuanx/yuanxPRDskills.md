# PRD 标注系统 — 完整工作流程与复用指南

> 适用场景：将可交互的 PRD 标注系统（蓝圈数字 + Popover + 可编辑文本 + 持久化）注入 H5 原型 HTML 页面。

---

## 一、可复用文件清单

将以下三个文件复制到**新项目根目录**，无需修改即可使用：

| 文件 | 作用 |
|---|---|
| `prd-server.js` | Node.js 服务：托管静态文件 + 提供 `/prd-save` 写入接口 |
| `prd-runtime.js` | 客户端运行时：页面启动时读取规则、覆盖 `savePrd` 实现双写 |
| `prd-data.json` | 规则存储文件（初始为 `{}`），随项目文件夹移动 |

---

## 二、首次接入新项目的完整步骤

### Step 1：复制核心文件

将 `prd-server.js`、`prd-runtime.js`、`prd-data.json` 放到项目根目录（与 HTML 文件同级）。

### Step 2：为每个 HTML 页面注入 prd-runtime.js

在每个页面 `</body>` 前插入（必须在页面内联 `<script>` 之后）：

```html
<script src="prd-runtime.js"></script>
</body>
```

PowerShell 批量注入（逐文件操作，中文路径用此方法）：

```powershell
$files = Get-ChildItem "C:\项目路径" -Filter "*.html"
foreach ($f in $files) {
  $c = Get-Content $f.FullName -Raw -Encoding utf8
  if ($c -notlike '*prd-runtime.js*') {
    $c = $c.Replace('</body>', '<script src="prd-runtime.js"></script>' + "`n</body>")
    Set-Content -Path $f.FullName -Value $c -Encoding utf8
  }
}
```

### Step 3：在每个 HTML 页面的内联 `<script>` 中写好标注数据

每页必须在 `</script>` 之前（即 prd-runtime.js 加载之前）定义：

```js
const prdData = {
  1: {
    title: '标记 1 · 规则标题',
    badge: '业务规则',        // 显示在 badge 上的文字
    badgeType: '',            // '' = 红色, 'interaction' = 绿色, 'data' = 蓝色
    text: '默认规则内容...'
  },
  2: {
    title: '标记 2 · 规则标题',
    badge: '交互规范',
    badgeType: 'interaction',
    text: '默认规则内容...'
  }
};
```

prd-runtime.js 加载后会自动：
- 读取 prd-data.json（服务器模式）或 localStorage（file:// 模式）
- 将已保存的规则文本覆盖到 prdData 对应条目
- 覆盖 `window.savePrd`，实现双写持久化

### Step 4：在 HTML 中放置标记

```html
<!-- 内联跟随内容流 -->
<span class="prd-mark" onclick="openPrd(event,1)">1</span>

<!-- 绝对定位（父容器需 position:relative） -->
<span class="prd-mark" onclick="openPrd(event,2)"
      style="position:absolute;top:12px;right:16px">2</span>

<!-- 固定悬浮 -->
<span class="prd-mark" onclick="openPrd(event,3)"
      style="position:fixed;bottom:80px;right:20px;z-index:50">3</span>
```

### Step 5：启动服务

```powershell
cd C:\项目根目录
node prd-server.js          # 默认 3000 端口
node prd-server.js 8080     # 指定端口
```

---

## 三、每页必须包含的 CSS + JS 模板

### CSS（放在 `</style>` 之前）

```css
.prd-mark{display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#1565C0;color:#fff;font-size:11px;font-weight:700;cursor:pointer;flex-shrink:0;transition:transform .12s;user-select:none;vertical-align:middle;margin-left:6px;box-shadow:0 2px 6px rgba(21,101,194,.4)}
.prd-mark:active{transform:scale(.85)}
.prd-overlay{position:fixed;inset:0;z-index:900;background:transparent}
.prd-popover{position:fixed;z-index:910;background:#fff;border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.18);width:290px;padding:0;overflow:hidden}
.prd-popover-arrow{position:absolute;width:12px;height:12px;background:#fff;transform:rotate(45deg);box-shadow:-2px -2px 5px rgba(0,0,0,.06)}
.prd-pop-head{padding:14px 16px 10px;border-bottom:1px solid #f0f0f0}
.prd-pop-title{font-size:13px;font-weight:700;color:#1A1A1A;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.prd-pop-badge{font-size:10px;padding:2px 7px;border-radius:8px;font-weight:600;background:#FDE8E8;color:#C62828}
.prd-pop-badge.interaction{background:#E8F5E9;color:#2E7D32}
.prd-pop-badge.data{background:#E3F2FD;color:#1565C0}
.prd-pop-body{padding:12px 16px}
.prd-pop-body textarea{width:100%;min-height:110px;border:1px solid #e0e0e0;border-radius:8px;padding:9px 10px;font-size:12px;line-height:1.6;color:#424242;resize:vertical;outline:none;background:#fafafa}
.prd-pop-body textarea:focus{border-color:#1565C0;background:#fff}
.prd-pop-foot{padding:10px 16px 14px;display:flex;gap:8px;justify-content:flex-end}
.prd-pop-foot button{padding:7px 16px;border-radius:8px;font-size:13px;font-weight:500;cursor:pointer;border:none}
.prd-btn-cancel{background:#f5f5f5;color:#424242}
.prd-btn-save{background:#1565C0;color:#fff}
```

### JS（放在内联 `</script>` 之前，prd-runtime.js 加载之前）

```js
// prdData 定义见上方 Step 3

function openPrd(e, id) {
  e.stopPropagation(); closePrd();
  const d = prdData[id]; const mark = e.currentTarget; const rect = mark.getBoundingClientRect();
  const overlay = document.createElement('div'); overlay.className = 'prd-overlay'; overlay.onclick = closePrd; document.body.appendChild(overlay);
  const pop = document.createElement('div'); pop.className = 'prd-popover'; pop.id = 'prdPop';
  const badgeCls = 'prd-pop-badge' + (d.badgeType ? ' ' + d.badgeType : '');
  pop.innerHTML = `<div class="prd-pop-head"><div class="prd-pop-title">${d.title}<span class="${badgeCls}">${d.badge}</span></div></div><div class="prd-pop-body"><textarea id="prdTa" spellcheck="false">${d.text}</textarea></div><div class="prd-pop-foot"><button class="prd-btn-cancel" onclick="closePrd()">取消</button><button class="prd-btn-save" onclick="savePrd(${id})">保存</button></div>`;
  const arrow = document.createElement('div'); arrow.className = 'prd-popover-arrow'; pop.appendChild(arrow); document.body.appendChild(pop);
  const popW = 290, popH = 280;
  const appRect = document.getElementById('app').getBoundingClientRect();
  let left = Math.min(rect.left - 10, appRect.right - popW - 8); left = Math.max(appRect.left + 8, left);
  const spaceBelow = window.innerHeight - rect.bottom - 12;
  let top, arrowTop;
  if (spaceBelow >= popH) { top = rect.bottom + 8; arrowTop = -6; } else { top = rect.top - popH - 8; arrowTop = popH - 6; }
  pop.style.left = left + 'px'; pop.style.top = top + 'px';
  const arrowLeft = Math.min(Math.max(rect.left - left + 4, 10), popW - 22);
  arrow.style.left = arrowLeft + 'px'; arrow.style.top = arrowTop + 'px';
  if (spaceBelow < popH) arrow.style.transform = 'rotate(45deg)';
}
function closePrd() {
  document.querySelector('.prd-overlay')?.remove();
  document.getElementById('prdPop')?.remove();
}
function savePrd(id) {
  // 此函数会被 prd-runtime.js 覆盖为双写版本
  // 以下为 file:// 降级兜底（正常不会执行到）
  const ta = document.getElementById('prdTa'); if (ta) prdData[id].text = ta.value;
  closePrd();
  if (typeof showToast === 'function') showToast('产品规则已保存');
}
```

---

## 四、持久化机制与访问方式

### 规则存储策略

| 场景 | 读取来源 | 写入目标 |
|---|---|---|
| `node prd-server.js` 启动后访问 | prd-data.json | prd-data.json + localStorage |
| Live Server / 其他静态服务 | prd-data.json（只读静态文件） | 仅 localStorage（POST 失败） |
| 直接双击 file:// 打开 | localStorage | localStorage |

### 推荐工作流

- **编辑规则**：用 `http://localhost:3000` 访问，保存后写入 prd-data.json
- **查看原型**：Live Server（如 192.168.x.x:端口）也能读取 prd-data.json，看到已保存规则
- **分享给他人**：把整个项目文件夹发出去，对方跑 `node prd-server.js` 即可

### 换端口不丢数据

```powershell
node prd-server.js 8080  # 换端口，prd-data.json 路径不变，规则全部保留
```

---

## 五、注入方式选择原则

| 页面特征 | 推荐方式 |
|---|---|
| 内容通过 `render()` 动态生成（template literal） | 全量重写，将标记直接写进 template string |
| 内容为静态 HTML | PowerShell `.Replace()` 定向注入 |
| 文件含复杂 template literal（>300行） | 注入前必须验证 backtick 偶数 |

---

## 六、核心技术经验

### 6.1 中文路径文件只能用 PowerShell 操作

Write / Edit 工具在路径含中文时会抛出 JSON 解析错误。唯一可靠方案：

```powershell
$c = Get-Content $p -Raw -Encoding utf8
# 修改 $c ...
Set-Content -Path $p -Value $c -Encoding utf8
```

始终用 `Set-Content`（覆盖），不用 `Add-Content`（追加）。

### 6.2 注入前必须验证 backtick 数量（偶数 = 合法）

```powershell
$bt = [regex]::Matches($c, '`')
Write-Host "Backtick count: $($bt.Count)"  # 必须为偶数
```

### 6.3 HTML 标记只能放在 `<body>` 区域，永远不能在 `<script>` 内

```powershell
# 验证标记没有落在 script 内：找到标记位置，确认前方最近的标签是 </script> 而非 <script>
$idx = $c.IndexOf('prd-mark')
Write-Host $c.Substring([Math]::Max(0,$idx-100), 200)
```

### 6.4 prd-data.json 必须无 BOM，写入必须用 `[System.IO.File]::WriteAllText`

PowerShell 5.1 的 `Set-Content -Encoding utf8` 默认写入带 BOM 的 UTF-8（`\uFEFF` 开头）。
Node.js `JSON.parse` 遇到 BOM 会抛 `Unexpected token '﻿'`，导致每次 POST 返回 400，规则永远写不进去。

**创建或重置 prd-data.json 必须用：**

```powershell
[System.IO.File]::WriteAllText(
  "路径\prd-data.json",
  "{}",
  [System.Text.UTF8Encoding]::new($false)   # $false = 无 BOM
)
```

prd-server.js 内也加了防御性剥离，双重保险：

```js
JSON.parse(fs.readFileSync(PRD_FILE, 'utf8').replace(/^\uFEFF/, ''))
```

### 6.5 `.Replace()` 比 `-replace` 更安全

`-replace` 是正则，`(`, `)`, `.`, `*` 等字符须转义。精确替换一律用：

```powershell
$c = $c.Replace($old, $new)
```

### 6.5 prd-runtime.js 必须在内联 script 之后加载

`prdData` 在内联 script 中定义，prd-runtime.js 启动时读取并覆盖 `savePrd`。
顺序错误（runtime 先于 prdData）会导致 `prdData is not defined`。

正确顺序：
```html
<script>
  const prdData = { ... };   // 1. 先定义数据
  function openPrd() { ... } // 2. UI 函数
  function savePrd() { ... } // 3. 原始 savePrd（会被覆盖）
</script>
<script src="prd-runtime.js"></script>  <!-- 4. 最后加载，覆盖 savePrd -->
</body>
```

### 6.6 Popover 定位算法

`#app` 设有 `overflow:hidden`，Popover 必须用 `position:fixed` + 视口坐标，并用 `appRect` 限制左右边界防止溢出。

---

## 七、注入后验证清单

```powershell
$c = Get-Content $p -Raw -Encoding utf8

# 1. backtick 偶数（template literal 完整性）
[regex]::Matches($c, '`').Count

# 2. 标记数量符合预期
[regex]::Matches($c, 'openPrd\(event').Count

# 3. prd-runtime.js 已注入且在最后一个 </script> 之后
$c.Contains('prd-runtime.js')
$c.LastIndexOf('</script>') -lt $c.IndexOf('prd-runtime.js')  # 应为 True... 注意此处是 src 标签本身包含 </script>，实际检查用 IndexOf('prd-runtime')

# 4. prdData 定义存在
[regex]::Matches($c, 'const prdData').Count  # 应为 1

# 5. prd-data.json 存在于项目根目录
Test-Path (Join-Path $projectRoot 'prd-data.json')
```

---

## 八、常见 Bug 速查

| 现象 | 根因 | 解决 |
|---|---|---|
| 页面空白 | span 注入到 `<script>` 内部 | 找到标记位置，移到 HTML 区域 |
| 页面空白 | backtick 奇数，template literal 断裂 | 打印所有 backtick 位置，逐一排查 |
| 规则刷新后消失 | prd-runtime.js 未注入 / 注入在 prdData 之前 | 检查注入顺序 |
| Live Server 上规则是旧的 | 在 Live Server 上保存的修改只写了 localStorage | 改用 localhost:3000 保存 |
| 换端口后规则丢失 | 误以为规则在 localStorage | prd-data.json 与端口无关，检查文件内容 |
| 标记位置错乱 | 绝对定位标记的父容器缺 `position:relative` | 给父容器加 `style="position:relative"` |
| Popover 超出屏幕 | 没用 appRect 限制边界 | left 值用 appRect 上下夹 |
| 点击标记无响应 | 外层 onclick 吞掉事件 | 检查父元素竞争事件，确认 `e.stopPropagation()` |
| savePrd 未被覆盖 | prd-runtime.js 加载在 prdData 定义之前 | 调整 script 标签顺序 |
