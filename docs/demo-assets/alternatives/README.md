# 没有设备时的演示替代方案

公开外观图用于演示页面和接口，手动错误码用于检查E24流程，暗化／模糊图用于检查重拍。真实故障识别仍需有故障标签的实拍样本；替代材料不等于完成这项验收。

## 六场景怎么跑

| 场景 | 已准备的替代材料 | 当前mock模式的预期 | 尚需验证 |
|---|---|---|---|
| S1 路由器 | 3张TP-Link照片，上传名`router-01..03.jpg` | 明确的离线演示步骤和模拟来源 | 照片真实故障、硬件修订号及手册匹配 |
| S2 洗碗机E24 | 3张Bosch外观照；手动输入Bosch／博世＋E24／E:24 | 外观照`e24-01..03.jpg`不支持mock诊断，返回422；手动输入返回`dishwasher`、`professional`、型号为空、无DIY步骤 | 照片实际显示E24、OCR与确切型号 |
| S3 BILLY | 3张书架照片，上传名`billy-01..03.jpg` | 演示步骤及防倾倒提醒 | 商品编号、组装错误、缺件 |
| S4 微波炉 | 3张外观照，上传名`microwave-01..03.jpg` | 安全拒答、无DIY步骤 | 对真实故障的识别能力 |
| S5 重拍 | 3张暗化图、3张模糊图，上传名`router-dark-*`／`router-blur-*` | 实际像素质量检查，返回422重拍提示 | 各种手机与拍摄环境的可靠性 |
| S6 报修 | 复用S1照片 | 反馈保存、双语草稿及会话读取 | 手机复制、系统分享及照片附件 |

共18个不同输入文件，S6复用S1照片。3张Bosch照片来自同一作者、同一设备的不同视角；TP-Link的3张也属于同一组，不能当作独立故障样本。mock响应中的路由器或BILLY型号是演示预设，不是对照片型号的识别结果。

## 来源和处理

3张Bosch照片由**Yelderberry**拍摄，许可为[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)。保存的是Commons的960×1280版本，未添加错误码、红灯或故障。原图4284×5712；下载链接、原图链接和校验值见`sources.json`。

- [Bosch照片1](https://commons.wikimedia.org/wiki/File:Bosch_Dishwasher_2026-08-23_1.jpg)
- [Bosch照片2](https://commons.wikimedia.org/wiki/File:Bosch_Dishwasher_2026-08-23_2.jpg)
- [Bosch照片3](https://commons.wikimedia.org/wiki/File:Bosch_Dishwasher_2026-08-23_3.jpg)

其他照片沿用`../public/sources.json`中的作者和许可。处理图选自13张原图对照：亮度乘0.15或原尺寸高斯模糊半径12像素，保存无损PNG。每个输入的作者、许可、来源和处理合并在`manifest.json`。再分发应同时附上这些说明。

## 当前接口与复跑

当前接口需登录，发送`Authorization: Bearer <token>`；注册／登录接口见`server/main.py`。图片接口为`POST /api/analyze/image`，multipart字段为`file`，可选语言字段为`language`。mock模式只处理明确的演示场景名或受支持的原始演示图片哈希；普通随机相册图片不应被当作真实识别结果。

手动输入接口为`POST /api/diagnose/manual`：

```json
{"brand":"Bosch","error_code":"E:24","language":"zh"}
```

mock模式预期返回`dishwasher`、`professional`、`model: null`和空步骤；这是用户提供错误码的演示，不是照片OCR。`E240`、未知品牌或未知错误码返回422，不得误配成E24。报修草稿不自动附照片，系统分享时由使用者另附。

在`server/`安装项目和测试依赖后运行：

```sh
python experiments/validate_data_assets.py
python -m pytest tests/test_demo_alternatives.py -q
```

当前26项用例（21次图片、5次手动输入）按清单逐条验证，其中包含拒绝用例；S6还检查反馈、中英文草稿和会话读取。测试使用隔离的临时数据库，强制mock模式，不调用真实模型。预期字段与当前API保持一致，不能将通过数量解释为故障识别准确率。

旧说明中的`evaluate_demo_alternatives.py`、`package_demo_assets.py`和`demo-alternative-results.json`未包含在集成仓库中；当前使用上面的验收测试，不再声称已有可复核的旧实验输出或自动打包工具。若需手工打包，按`manifest.json`的`source_file`复制18个文件，以`demo_name`命名，并保留清单、来源和本说明。

完整App仍需补充实机拍摄、重拍、分享和真实耗时。是否以替代材料满足本次课堂展示范围，由团队确认；真实故障实拍验收应继续标为待完成。
