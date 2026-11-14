# SnapFix Demo Narration / SnapFix 演示解说

- **Video / 视频：** `docs/video/snapfix-full-demo.mp4`
- **Duration / 时长：** 2:09（128.6 秒）
- **Version / 版本：** Current edited simulator recording / 当前剪辑版实机录屏

## 使用方式

- 课程视频建议只录 **英文旁白**，中文用于理解、核对和准备现场问答。
- 如果需要中文版本，可单独使用中文解说重新配音，不要在同一版本中连续朗读两种语言。
- 英文按每分钟约 140–150 词录制。段落之间可稍作停顿，但不要改变画面顺序。
- 当前画面实际演示的是**邮箱登录**；Apple 和 Google 只展示为可用入口，不要说成已完成第三方授权演示。

---

## 00:00–00:12 | Sign in / 登录

### English narration

> SnapFix helps users understand appliance problems and choose a safe next step. Sign in with email, or continue with Apple or Google. Your repair history stays with your account.

### 中文解说

> SnapFix 帮助用户了解家电故障，并选择安全的下一步。用户可以使用邮箱登录，也可以通过 Apple 或 Google 继续。维修档案会保存在自己的账号中。

**画面重点：** 登录页、邮箱登录、Demo User 首页。

---

## 00:12–00:28 | Photo diagnosis / 拍照诊断

### English narration

> Start with a photo from the camera or library. SnapFix checks the image, then uses Qwen3-VL to identify visible evidence. Here, it recognizes a TP-Link router and a red indicator, but does not invent model-specific repair steps.

### 中文解说

> 用户可以直接拍照，也可以从相册选择图片。SnapFix 先检查照片，再使用 Qwen3-VL 识别可见信息。这里它识别出 TP-LINK 路由器和红色指示灯，但在型号不明确时，不会编造针对性的维修步骤。

**画面重点：** 新建诊断、相册选图、照片预览、分析过程和路由器诊断结果。

---

## 00:28–00:52 | Manual-grounded repair / 基于手册的维修指引

### English narration

> For an error code, enter the brand and code directly. This Bosch E24 query retrieves relevant sections from a real dishwasher manual using BM25. Each repair step cites the original excerpt, PDF page, and chunk ID. Users can inspect the evidence, mark a step complete, and tap again to undo it.

### 中文解说

> 对于错误码，用户可以直接输入品牌和代码。这次 Bosch E24 查询通过 BM25，从真实的洗碗机手册中检索相关内容。每个维修步骤都附有手册原文、PDF 页码和 chunk ID。用户可以核对依据，将步骤标记为完成，也可以再次点击撤销。

**画面重点：** Bosch E24 查询、DIY 建议、真实手册引用、原文展开、完成与撤销。

---

## 00:52–01:20 | Safety and repair request / 安全拒答与报修

### English narration

> High-risk repairs follow a different path. For a microwave, deterministic safety rules stop DIY instructions and recommend qualified help. The diagnosis then becomes a bilingual repair request. Users can switch languages, edit details such as availability, save a draft, and copy or share the text. Photos are added manually, so the app does not claim they were attached.

### 中文解说

> 高风险维修会进入另一条处理路径。对于微波炉，确定性的安全规则会阻止 DIY 指引，并建议寻找专业维修人员。诊断结果随后可以转换成双语报修信息。用户可以切换语言，补充可预约时间等内容，保存草稿，再复制或分享文字。照片需要手动添加，因此 App 不会声称照片已经自动附上。

**画面重点：** 微波炉安全拒答、不提供 DIY 步骤、报修入口、中英文切换、编辑和保存草稿。

---

## 01:20–01:44 | Repair history / 维修档案

### English narration

> Repair history keeps the whole journey in one place. Each record shows the appliance, issue summary, sources, and current progress. Change the router status to Awaiting repair, then use the filters to find it again. This makes it easy to continue an earlier repair instead of starting over.

### 中文解说

> 维修档案将整个过程保存在一起。每条记录都显示设备、故障摘要、来源和当前进度。这里把路由器的状态改为“等待维修”，再通过筛选重新找到它。用户可以继续处理之前的故障，而不必从头开始。

**画面重点：** 三条档案记录、状态修改、Awaiting repair 筛选和进度展示。

---

## 01:44–02:09 | Preferences and closing / 偏好设置与结尾

### English narration

> Profile settings cover account security, language, appearance, motion, and notifications. Switch between light and dark mode, or between English and Simplified Chinese. Preferences sync with the account. SnapFix combines multimodal AI, real manual evidence, and deterministic safety in one practical workflow: snap it, fix it, or report it safely.

### 中文解说

> 个人中心提供账号安全、语言、外观、动态效果和通知设置。用户可以切换日间或夜间模式，也可以切换英文和简体中文，偏好会随账号同步。SnapFix 将多模态 AI、真实手册证据和确定性的安全规则结合起来，形成一条完整的实用流程：拍下来，安全维修，或者清楚报修。

**画面重点：** 个人中心、日夜间切换、中英文界面和跨设备偏好同步说明。

---

## 配音与字幕备注

- **Qwen3-VL** 读作 “Q-wen three V L”。
- **BM25** 读作 “B M twenty-five”。
- **E24** 读作 “E twenty-four”。
- **DIY** 读作 “D I Y”。
- 路由器结果的重点是**不编造型号和步骤**，不要将 “Call a professional” 解说成识别失败。
- E24 的真实检索结果是 **Bosch dishwasher manual**，不要说成 washing machine。
- “Deterministic safety rules” 指由明确规则执行的安全限制，不是让模型自行决定是否危险。
- 若添加字幕，使用英文旁白作为字幕原文；中文字幕可作为另一字幕轨，不必同时显示两种语言。
