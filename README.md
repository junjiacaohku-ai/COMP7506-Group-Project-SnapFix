# SnapFix 随手修(solo 完整版)

> 先搞懂,再决定。拍一张照片 → 哪坏了、能不能自己修、怎么修、修不了怎么报修。
> 本仓库为单人完整实现,与团队版并行开发,作为演示/交付的完整备份。

## 架构

```
server/  FastAPI 后端:质量门 → Gemini vision → 安全门 → 手册检索 → 生成 → 引用校验
app/     Flutter 双端 App(iOS / Android)
```

无 `GEMINI_API_KEY` 时后端自动进入 **mock 确定性模式**:全管线可演示,数据写死在
`server/mock_data.py`(覆盖 6 个验收场景);有 key 即走真实管线,接口契约不变。

## 运行

```bash
# 后端(Python 3.11+)
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 可选:填入 GEMINI_API_KEY 启用真管线
uvicorn main:app --reload --port 8001   # → http://127.0.0.1:8001/docs

# 前端(另开终端)
cd app && flutter run   # iOS 模拟器直接访问 127.0.0.1:8001;Android 模拟器改 10.0.2.2
```

## 演示场景对照(mock 模式)

| 场景 | 触发方式 | 预期 |
|---|---|---|
| 路由器红灯 | 拍/传文件名含 router/tplink 的照片 | 识别 TP-Link,4 步带引用排查 |
| 洗衣机 E24 | 错误码速查输 Bosch + E24 | 排水滤网清理 3 步 + 适合自己修 |
| IKEA BILLY | 文件名含 ikea/billy | 组装步骤 + 防倾倒警示 |
| 微波炉 | 文件名含 microwave/微波炉 | **安全门拒答**,零步骤 |
| 模糊/过暗照片 | 任一过暗过小照片 | 质量门 422 + 重拍引导 |
| 报修闭环 | 任一诊断后点"生成报修信息" | 中英双语报修文本,可复制/分享 |

文件名无关键词时按图片哈希确定性轮换(同图同结果,拒答场景不进轮换)。

## 安全与隐私

- 安全门(`safety_gate.py`)规则分类先于生成,12 类高危类目命中即短路拒答
- 引用校验:生成步骤的引用不在检索片段集合内即丢弃,宁缺毋假
- 照片处理后即删,不落盘;无账号无追踪
