# YuanX 原型可复用逻辑清单

> 核心创新：**把 PRD 文档嵌入原型页面**，点击蓝色数字标记即可查看/编辑该位置的产品规则，保存后持久化到文件，原型与文档永远同步。
>
> 最后更新：2026-08-11

---

## 目录

1. [PRD 标注系统（核心）](#1-prd-标注系统)
2. [持久化方案：prd-server + localStorage 双写](#2-持久化方案)
3. [移动端原型布局框架（390×844）](#3-移动端布局框架)
4. [设计 Token / CSS 变量](#4-设计-token)
5. [底部导航栏](#5-底部导航栏)
6. [新项目接入步骤 + 给 AI 的执行指令](#6-新项目接入步骤)

---

## 1. PRD 标注系统

### 1.1 核心文件

| 文件 | 作用 |
|------|------|
| `prd-runtime.js` | 统一运行时：openPrd / savePrd / 数据加载，所有页面共用 |
| `prd-server.js` | Node.js 静态服务器 + `/prd-save` POST 接口，把标注存进 `prd-data.json` |
| `prd-data.json` | 所有页面标注内容的持久化文件（按 pageName 分组） |

### 1.2 每个页面需要做的三件事

**① CSS（复制到页面 `<style>` 内，所有页面一样）**

```css
.prd-mark{display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:50%;background:#1565C0;color:#fff;font-size:11px;font-weight:700;cursor:pointer;flex-shrink:0;transition:transform .12s;user-select:none;vertical-align:middle;margin-left:6px;box-shadow:0 2px 6px rgba(21,101,194,.4);position:relative;z-index:5}
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
.prd-pop-body textarea{width:100%;min-height:110px;border:1px solid #e0e0e0;border-radius:8px;padding:9px 10px;font-size:12px;line-height:1.6;color:#424242;resize:vertical;outline:none;background:#fafafa;transition:border .15s}
.prd-pop-body textarea:focus{border-color:#1565C0;background:#fff}
.prd-pop-foot{padding:10px 16px 14px;display:flex;gap:8px;justify-content:flex-end}
.prd-pop-foot button{padding:7px 16px;border-radius:8px;font-size:13px;font-weight:500;cursor:pointer;border:none}
.prd-btn-cancel{background:#f5f5f5;color:#424242}
.prd-btn-save{background:#1565C0;color:#fff}
```

**② HTML 中放置标记（紧跟在需要标注的元素后面）**

```html
<!-- 内联标注 -->
<span class="feature-title">某功能</span>
<span class="prd-mark" onclick="openPrd(event,1)">1</span>

<!-- 固定在卡片右上角 -->
<span class="prd-mark" style="position:absolute;top:12px;right:12px" onclick="openPrd(event,2)">2</span>
```

**③ script 中定义 prdData，然后引入 prd-runtime.js（必须在 prdData 之后）**

```html
<script>
const prdData = {
  1: {
    title: '标记 1 · 功能名称',
    badge: '交互规则',
    badgeType: 'interaction',   // interaction=绿 / data=蓝 / 空=红
    text: '详细说明...\n\n• 业务规则\n• 数据来源\n• 边界条件'
  },
  2: {
    title: '标记 2 · 数据字段',
    badge: '数据规范',
    badgeType: 'data',
    text: '字段说明...'
  }
};
</script>
<script src="prd-runtime.js"></script>
```

### 1.3 prd-runtime.js 的能力

- 启动时自动从 `prd-data.json`（服务器模式）或 `localStorage`（file:// 模式）加载已保存内容，**覆盖** prdData 默认值
- `openPrd(e, id)`：弹出可编辑 popover，支持修改标题 / 标签 / 序号 / 正文四个字段
- `savePrd(id)`：localStorage 备份 + POST `/prd-save` 写服务器（双写）
- popover 自动避开屏幕边缘，上下方向自适应
- 圆圈序号文字可自定义（如改成图标字符）

---

## 2. 持久化方案

### 2.1 为什么必须用 localhost:3000，不能直接双击 html

`prd-runtime.js` 用 `fetch('prd-data.json')` 加载数据。直接双击 html（`file://` 协议）浏览器会拦截 fetch 请求，导致标注内容无法持久化，每次刷新都会显示代码里的默认值。

**必须用 `node prd-server.js` 启动后访问 `http://localhost:3000`**

### 2.2 启动命令

```bash
cd 项目目录
node prd-server.js
# 访问 http://localhost:3000
```

### 2.3 prd-data.json 数据结构

```json
{
  "fenxi": {
    "1": { "markLabel": "1", "title": "标记标题", "badge": "类型", "text": "内容" }
  },
  "cuoti": {
    "1": {}
  }
}
```

pageName 自动取自 URL 文件名去掉 `.html`，无需手动配置。

---

## 3. 移动端布局框架

```css
body {
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Microsoft YaHei', sans-serif;
  background: #e8e8e8;
  overflow: hidden;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
}
#app {
  width: 100%;
  max-width: 390px;
  height: 100vh;
  max-height: 844px;
  background: var(--bg);
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: 0 0 40px rgba(0,0,0,.15);
}
@media(max-width:420px){ #app { max-height:100vh; box-shadow:none } }
```

页面结构三段式：

```html
<div id="app">
  <div class="app-bar"><!-- 顶部标题栏，flex-shrink:0 --></div>
  <div class="page-body"><!-- 可滚动内容区，flex:1; overflow-y:auto --></div>
  <div class="bottom-nav"><!-- 底部导航，flex-shrink:0 --></div>
</div>
```

---

## 4. 设计 Token

```css
:root {
  --primary:   #E6431A;   /* 主色橙红 */
  --bg:        #F5F5F7;   /* 页面背景 */
  --surface:   #FFFFFF;   /* 卡片背景 */
  --text1:     #1A1A1A;
  --text2:     #424242;
  --text3:     #616161;
  --hint:      #9E9E9E;   /* 非激活图标 */
  --divider:   #EAEAEA;
  --urgent:    #E53935;   /* 红色警示 */
  --attention: #FBC02D;   /* 黄色提示 */
  --keep:      #43A047;   /* 绿色正向 */
  --r-card:    14px;
  --r-btn:     10px;
}
```

---

## 5. 底部导航栏

```html
<!-- head 中引入图标库 -->
<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">

<div class="bottom-nav">
  <a class="nav-item active" href="page1.html">
    <span class="material-icons">insights</span>
    <span class="nav-label">分析</span>
  </a>
  <a class="nav-item" href="page2.html">
    <span class="material-icons">forum</span>
    <span class="nav-label">社区</span>
  </a>
</div>
```

```css
.bottom-nav{background:var(--surface);height:56px;display:flex;align-items:center;justify-content:space-around;border-top:1px solid var(--divider);flex-shrink:0}
.nav-item{display:flex;flex-direction:column;align-items:center;cursor:pointer;padding:4px 0;border:none;background:none;min-width:50px;text-decoration:none}
.nav-item .material-icons{font-size:24px;color:var(--hint)}
.nav-item .nav-label{font-size:10px;color:var(--hint);margin-top:2px}
.nav-item.active .material-icons,.nav-item.active .nav-label{color:var(--primary);font-weight:500}
```

---

## 6. 新项目接入步骤

### 快速接入

1. 复制以下三个文件到新项目根目录：`prd-runtime.js` / `prd-server.js` / `prd-data.json`（空文件 `{}` 即可）
2. 每个 HTML 页面按 1.2 节三步添加 CSS / 标记 / prdData + script 引用
3. 启动：`node prd-server.js`
4. 访问 `http://localhost:3000/页面.html`，点蓝色圆圈开始编写 PRD
5. 标注自动保存到 `prd-data.json`，随代码一起提交 git 即可交付

---

### 给 AI 的执行指令（直接复制给 Claude）

```
参考 yuanx 项目的 prd-runtime.js、prd-server.js，在当前项目的每个 HTML 原型页面中：

1. 在 <style> 里加入 PRD 标注系统 CSS（见 REUSABLE_PATTERNS.md 第 1.2 节 ① 的完整 CSS 块）

2. 在页面各关键功能点旁插入标注标记：
   <span class="prd-mark" onclick="openPrd(event,N)">N</span>

3. 在 </body> 前定义 prdData 对象，为每个标记写好 title / badge / badgeType / text：
   const prdData = { 1: { title:'...', badge:'...', badgeType:'interaction|data|', text:'...' }, ... };

4. prdData 之后紧跟：
   <script src="prd-runtime.js"></script>

5. 确保项目根目录有 prd-runtime.js / prd-server.js / prd-data.json 三个文件

6. 所有文件写入后用 node prd-server.js 启动，访问 http://localhost:3000 验证标注可点击、可保存
```
