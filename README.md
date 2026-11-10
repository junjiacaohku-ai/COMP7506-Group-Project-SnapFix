# SnapFix 随手修（solo 完整版）

> 先搞懂，再决定。拍一张照片 → 哪坏了、能不能自己修、怎么修、修不了怎么报修。
> 本仓库为单人完整实现，与团队版并行开发，作为演示/交付的完整备份。

## 架构

```
server/  FastAPI 后端：质量门 → 视觉模型 → 安全门 → 手册检索 → 生成 → 引用校验
app/     Flutter 双端 App（iOS / Android）
```

支持 **阿里云百炼 Qwen3-VL** 和 **Google Gemini**。没有可用模型配置时，后端进入
明确标识的 **mock 确定性演示模式**，数据位于 `server/mock_data.py`。
真实在线模式失败时会明确报错或停止提供无依据步骤，**不会返回无关 mock 场景冒充真实识别**。

## 运行

```bash
# 后端（Python 3.11+）
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 可选：填入模型配置启用真管线
uvicorn main:app --reload --port 8001   # → http://127.0.0.1:8001/docs

# 前端（另开终端）
cd app && flutter run   # iOS 模拟器直接访问 127.0.0.1:8001；Android 模拟器改 10.0.2.2
```

健康检查：`GET /api/health`。`provider` 返回 `qwen`、`gemini` 或 `mock`。

## Qwen 真实诊断配置

1. 在阿里云 Model Studio（百炼）开通服务，选择 **中国香港** 地域。
2. 在同一地域创建 API Key，并确认模型 `qwen3-vl-plus` 可用。
3. 在 `server/.env` 配置：

```bash
AI_PROVIDER=qwen
DASHSCOPE_API_KEY=你的Key
DASHSCOPE_BASE_URL=https://cn-hongkong.dashscope.aliyuncs.com/compatible-mode/v1
QWEN_MODEL=qwen3-vl-plus
```

也可将 `DASHSCOPE_BASE_URL` 换为工作空间详情中的 API Host，并保留
`/compatible-mode/v1`。Key、地域与 Base URL 必须匹配。`.env` 已被 Git 忽略，
不要提交真实 Key。

使用 Gemini 时设置 `AI_PROVIDER=gemini` 和 `GEMINI_API_KEY`。App 会把当前界面
语言传给后端，真实 AI 的决策理由、步骤和安全说明使用中英文生成；手册引用保留原文。

## 真实账号与个人档案

首次打开需注册或登录。支持邮箱 + 密码、Sign in with Apple；Google 登录在配置
OAuth Client ID 后启用。不提供未接入的验证码或找回密码入口。密码使用 PBKDF2
加盐哈希；访问令牌保存在设备 Keychain / Android Keystore，服务器只保存令牌哈希。
诊断、步骤反馈、删除与报修接口均按当前用户隔离。

界面默认使用 English，可在登录页右上角或个人中心的“语言”切换为简体中文。
语言选择保存在设备上，重启后保留。界面文案随语言切换，手册引用保留来源语言。

Apple 使用原生授权、一次性 nonce 与服务端 JWKS/JWT 校验。Apple / Google 身份通过
`auth_identities` 关联账号；已验证邮箱相同则复用现有用户，不创建重复账号。
Apple 需要有效的 Apple Developer Program 配置，并已为 App ID 启用 Sign in with Apple。

### Google OAuth 配置

1. 在 Google Cloud 配置 OAuth 同意屏幕，创建 **iOS** 类型的 OAuth Client ID，
   bundle id 使用 `hk.snapfix.snapfixSolo`。
2. 推荐另建 **Web application** 类型的 OAuth Client ID，供后端验证 ID Token。
   开发环境也可只使用 iOS Client ID，此时将 `GOOGLE_SERVER_CLIENT_ID` 留空。
3. 在 `server/.env` 设置 `GOOGLE_CLIENT_ID` 为 iOS Client ID，
   `GOOGLE_SERVER_CLIENT_ID` 为 Web application Client ID。后端优先使用后者，
   未设置时回退到 iOS Client ID。
4. 在 `app/ios/Flutter/Auth.xcconfig` 填入 iOS Client ID、对应的 reversed Client ID，
   以及 Web application Client ID。
5. 启动 App 时传入同一组配置：

```bash
flutter run \
  --dart-define=GOOGLE_CLIENT_ID=你的-iOS-Client-ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=你的-Web-Client-ID
```

未配置 iOS Client ID 时 Google 按钮隐藏；后端没有可用的 Client ID 时，
OAuth 接口返回 503，不会伪造登录结果。

## 演示场景对照（mock 模式）

| 场景 | 触发方式 | 预期 |
|---|---|---|
| 路由器红灯 | 拍/传文件名含 router/tplink 的照片 | 识别 TP-Link，4 步带引用排查 |
| 洗衣机 E24 | 错误码速查输 Bosch + E24 | 排水滤网清理 3 步 + 适合自己修 |
| IKEA BILLY | 文件名含 ikea/billy 的照片 | 组装步骤 + 防倾倒警示 |
| 微波炉 | 文件名含 microwave/微波炉的照片 | **安全门拒答**，零步骤 |
| 模糊/过暗照片 | 任一过暗过小照片 | 质量门 422 + 重拍引导 |
| 报修闭环 | 任一诊断后点“生成报修信息” | 中英双语报修文本，可复制/分享 |

文件名无关键词时按图片哈希确定性轮换（同图同结果，拒答场景不进轮换）。
mock 仅替换诊断数据源，账号与个人档案仍使用真实后端流程。

## 安全与隐私

- 安全门（`safety_gate.py`）规则分类先于生成，12 类高危类目命中即短路拒答。
- 引用校验：生成步骤的引用不在检索片段集合内即丢弃，宁缺毋假。
- 没有匹配手册或 DIY 步骤全部未通过校验时，转为专业帮助，不伪造操作指引。
- 照片处理后即删，不落盘；在线模式会将照片发送至所配置的模型服务。
- 诊断记录按账号隔离，无行为追踪。

## 已知问题

- **iOS 26.3 模拟器不渲染瞬时提示（toast）**：错误提示/复制成功等短驻留 UI
  （SnackBar/自动关闭 dialog）在该模拟器上不上屏，静态对话框与底部表单正常。
  已用 10+ 种实现交叉验证定位为模拟器/Impeller 渲染层怪癖，非应用逻辑问题；
  代码使用标准 `ScaffoldMessenger.showSnackBar`，需在真机上复核。
  详见 `docs/openissues-2026-10-23.md`。
