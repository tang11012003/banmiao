# 陪读社区 App - Flutter 前端

面向高考家长的移动社区 App（工具 + 社区，对标美柚）。后端 Go(gin) 运行于 `http://localhost:8080`，
接口以 `Authorization: Bearer <token>` 鉴权。本工程对接 PRD V1.0 的 FR-AUTH / FR-CAL / FR-PAP / FR-COM 四大模块。

## 技术栈

- **Flutter 3.0 / Dart 2.17**（已验证 `flutter analyze` 通过）
- 网络请求：`dio`（含 JWT 拦截器 + `{code,message,data}` 信封统一解析）
- 状态管理：`provider`（全局注入 ApiClient 与 AuthProvider）
- 图表：`fl_chart`（三档分布环形图、得分率/知识点趋势折线图）
- 图片：`image_picker`（拍照/相册选图上传）
- 持久化：`shared_preferences`（token 持久化）
- 日期：`intl`

## 本地运行

```bash
cd frontend
flutter pub get
flutter analyze      # 预期：No issues found!
flutter run          # 真机/模拟器联调（需启动后端）
```

> 真机联调请将 `lib/config/constants.dart` 中的 `ApiConstants.baseUrl` 改为可访问的局域网/公网地址。

## 目录结构

```
frontend/
├── pubspec.yaml
└── lib/
    ├── main.dart                 # 入口：MaterialApp + 路由表 + 全局 Provider 注入
    ├── config/constants.dart     # baseUrl、接口路径、认证方式/三档枚举、默认圈子
    ├── api/client.dart           # 基于 dio 的 REST 封装（自动带 JWT + 统一 JSON 解析）
    ├── models/                   # 数据模型（snake_case，与后端 model.go 对齐）
    │   ├── user.dart  auth.dart  calendar.dart  exam.dart
    │   ├── paper.dart  community.dart
    ├── providers/
    │   ├── auth_provider.dart    # 登录态、token 持久化、认证角色、短信验证码流程
    │   └── tracker.dart          # 轻量埋点（打印日志）
    ├── widgets/
    │   ├── common_widgets.dart   # 倒计时卡片 / 考试卡片 / 三档知识点卡片 / 日期格式化
    │   └── charts.dart           # 三档环形图 + 趋势折线图（fl_chart）
    └── features/
        ├── auth/                 # 登录(login_page) + 家长认证(verification_page)
        ├── calendar/             # 高考日历：倒计时/模板/事件/模拟考成绩
        ├── paper/                # 上传(paper_upload) / 报告(paper_report) / 数据看板(dashboard)
        ├── community/            # 信息流 / 详情 / 发帖
        ├── profile/              # 个人中心：认证、次数、邀请码
        ├── home/                 # 首页（倒计时 + 上传入口 + 近期考试 + 热门话题）
        └── shell.dart            # 底部导航 [首页][社区][日历][我的]
```

## 接口对接（以后端代码为准）

| 模块 | 页面 | 对接接口 |
|------|------|----------|
| 鉴权 | login/verification | send-sms, login, users/profile, users/verification(±status), users/quota |
| 日历 | calendar | calendar/countdown, calendar/templates, calendar/events(±), calendar/exams |
| 试卷 | paper_upload/report/dashboard | papers/upload(multipart), papers/:id/report, papers/trend, papers/knowledge/:kpId/trend, papers/tier-distribution, papers/:id/share |
| 社区 | community/* | community/posts(±), posts/:id, posts/:id/comments, community/comments, like, follow, community/share-report |
| 邀请 | profile | invites/generate, invites, invites/use |

关键埋点（tracker 打印日志）：上传试卷 `paper_upload_success`、生成分享 `paper_share`/`share_to_community`、发帖 `community_post`、邀请码 `invite_generate`/`invite_used`。

## 设计要点

工具与社区分离、工具结果可分享到社区：报告页与发帖页均提供「分享到社区」入口，调用
`POST /api/community/share-report`，体现 PRD 核心架构原则。

## 残留风险 / 待联调项

1. **圈子列表接口缺失**：后端当前未提供 `GET /api/community/circles`，发帖/分享的 `circle_id`
   暂用 `lib/config/constants.dart` 中的 `DefaultCircles` 本地占位，接入圈子接口后替换。
2. **学生信息创建接口缺失**：`POST /api/calendar/exams` 的 `student_id` 为必填，但后端未暴露建学生接口，
   日历「记录成绩」需手动输入 student_id（仅演示用），建议补充 `POST /api/students`。
3. **OCR 为同步处理**：后端 `papers/upload` 同步完成 OCR 并返回 `completed` 的 Paper，前端上传后直接拉报告；
   报告页保留 1s 轮询重试（≤5 次）以兼容未来异步化。
4. **认证材料为占位**：开发态 `material_image` 传占位串，未真正接入 image_picker 上传到对象存储。
5. **注意事项**：未修改 backend 与 ocr-service 代码；字段命名保持 snake_case 与后端一致。
