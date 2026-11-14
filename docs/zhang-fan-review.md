# 张帆工作线检查与验收记录

检查日期：2026-11-14（UTC+8）。基线提交：`08bb5fa1ecf673c2bf898e93919d4b0dec049681`；本记录对应其后的修正，提交及合并状态以 GitHub 为准。

README 与报告均将 Zhang Fan／张帆列为“数据与内容”：语料 ETL、演示场景、市场调研、验收记录、带来源的公开图片。这五项已有实际成果；本次补齐了可复跑的离线验收、修正了错误演示和过期说明。真实模型、真机和最终视频仍有待办，不能将整个交付标为全部完成。以下核对的是仓库成果，不以分工表推断每个文件的历史作者。

## 逐项完成情况

| 分工 | 文件依据 | 本次检查结果 | 状态与剩余工作 |
|---|---|---|---|
| 语料 ETL | `server/corpus.py`、`server/corpus_store.py`、`server/data/manifest.json`、`inventory.csv`、`chunks.json`、`extraction-audit.json` | 从16份PDF完整重建，2,032个文本块、手册索引与页面审计均与提交版本逐字节一致；来源哈希一致 | 实现及离线复现完成。599页中548页有提取文本、45页稀疏、6页无法解码而排除；1页有绑定源哈希的视觉修正。不能声称每页维修知识均经过专家审核 |
| 演示场景 | `server/mock_data.py`、`pipeline.py`、`docs/demo-assets/demo-manifest.json`、`alternatives/manifest.json` | S1–S6通过认证接口验证；修正Bosch E24类别、未知图误匹配与热水器内部操作；另有26项替代输入检查 | 离线场景完成。公开外观照不是确认故障照片；实时AI能力须另验收 |
| 市场调研 | `docs/report/snapfix-report.tex` 的 Background Research；参考文献 | 已比较iFixit/FixBot、Frontdoor、Google Lens，另列FixIt Lens工程参考；2026-11-14复核官方来源，现有能力描述有依据 | 文献比较完成；未宣称产品实测或量化优胜 |
| 验收记录 | `docs/validation.md`、本记录、`docs/acceptance/2026-11-14/`、`server/tests/` | 原46项后端测试通过；修改后81项通过。新增离线素材核验命令，保留结果文件 | 本次离线记录完成；在线Qwen和真机记录仍待补齐 |
| 图片素材与来源 | `docs/demo-assets/public/sources.json`、`alternatives/sources.json`、`quality/manifest.json` | 14个公开JPG记录对应13张唯一照片；3张补充Bosch照片；18个替代输入、26张处理图。记录哈希全部一致，署名字段齐备 | 本地来源与完整性检查完成。再分发仍需保留作者、许可及修改说明；未将这些照片认定为真实故障标签 |

## 已修正的问题

1. **Bosch E24类别与依据错误**：旧mock给出洗衣机拆泵步骤，与真实洗碗机语料及S2清单不一致。现在仅支持Bosch／博世＋归一化后的E24，返回`dishwasher`、`professional`、型号为空、无维修步骤；其他品牌或代码422。原`demo-photos/washer_e24.jpg`作为历史合成素材保留，但不再是有效演示输入。在线结果仍由实际检索与校验决定。
2. **无关图片误匹配**：旧平均颜色匹配会把普通灰白图归入演示家电。现在无场景文件名时，只接受受支持原始router／IKEA／microwave图片的精确SHA-256；重编码图片需显式场景文件名。文件名选择只用于mock，不是图像识别证据。
3. **演示绕过安全检查**：移除热水器侧盖内复位等内部操作，热水器改为无步骤安全拒答；mock输出也经过确定性安全门。回归检查包含注入危险演示步骤的拦截。
4. **过期素材说明**：四份素材说明引用了不存在的评测、打包脚本及结果文件，还使用旧的无认证接口。现改为当前认证接口、替代输入清单和实际存在的验收测试；不再保留无法复核的旧上传通过声明。
5. **报告与README的证据强度**：更新本次81项后端结果；Flutter五项测试、静态分析与旧Qwen摘要标明本次未重跑。同步LaTeX与PDF，补充语料实际提取覆盖与工作线证据链接。
6. **手动查询错误提示**：手动错误码请求返回422时，不再显示“照片不清楚”的重拍弹窗，而是返回原表单并显示服务说明，保留品牌和错误码输入。新增两项界面回归测试，但当前环境没有Flutter SDK，尚未执行。
7. **视频计划与实际混淆**：链接已存在的MP4和解说稿，区分原2:50分镜与现有2:09剪辑，修正“模拟器录屏”表述及未演示第三方登录的旁白。

## 本次验收证据

| 检查 | 结果 | 记录 |
|---|---|---|
| 后端基线 | 46 passed，修正前通过 | 基线复跑；最终记录见下行 |
| 后端最终全套 | **81 passed in 32.75s**；46原有＋7主场景回归＋2素材完整性＋26替代输入 | [测试输出](acceptance/2026-11-14/backend-pytest.txt) |
| 素材与语料完整性 | 本地校验通过；不调用模型 | [核验结果](acceptance/2026-11-14/data-integrity.json) |
| 完整PDF语料重建 | 三个生成JSON逐字节一致 | [哈希与重建结果](acceptance/2026-11-14/corpus-rebuild.json) |
| 视频解码 | 3,859帧完整解码；128.633秒，720×1566竖屏，H.264＋AAC | [解码记录](acceptance/2026-11-14/video-decode.txt) |
| 视频音频 | 12,347,392个解码采样；峰值和RMS均为0；**现有视频静音** | 同上；旁白未完成 |
| Flutter／Qwen／真机 | 本次未执行；新增两项手动／照片错误提示界面测试尚未运行，没有将旧摘要当作本次通过结果 | 按[验证指南](validation.md)补录 |

环境为macOS／Python 3.12，项目声明的后端及开发依赖安装在独立环境；精确版本见[测试环境](acceptance/2026-11-14/environment.txt)。测试强制mock、使用临时SQLite，不访问真实模型或原有账号数据库。

复跑（先按README安装项目及开发依赖）：

```sh
cd server
python experiments/validate_data_assets.py
python -m pytest tests -q
python corpus.py data/manifest.json /tmp/snapfix-corpus-check/chunks.json
```

最后一条将语料重建到临时目录，不覆盖项目数据。比对`chunks.json`、`manuals.json`和`extraction-audit.json`即可复核重建结果。

## 视频缺口与补拍清单

本次保留原MP4，不添加配音或字幕；以下仅记录后续制作建议。操作镜头结论来自抽样，时间为近似值，不据此判断功能缺失。

现有文件：[演示MP4](video/snapfix-full-demo.mp4)，SHA-256：`87884caaafa00e4b49f337afa546a4c16b421aab526dfe8e659aa39b3b717300`。完整视频、音频轨道解码均成功；音频全部静音。没有字幕轨，抽样画面未见烧录字幕。目视抽查81个时间点，仅见Demo User及演示邮箱；这不等于逐帧隐私复核。

| 镜头 | 实际情况 | 最终版需完成 |
|---|---|---|
| 0–12秒登录 | 邮箱登录；Apple／Google仅按钮；约5–10秒出现缺少密码提示 | 剪掉无意的错误提示；解说只称邮箱登录 |
| 33–51秒E24 | 有洗碗机手册名、p35及chunk ID；抽样时原文折叠，未见完成／撤销 | 补录来源原文展开及反馈撤销。画面中涉及siphon连接和排水泵盖的指引，须核对具体型号与安全适用性后才复用；不得直接作为本次通过证据 |
| 66–85秒报修 | 中文页为加载，随后展示英文正文及演示预约时间 | 补录中文正文、保存结果及复制／分享；尚未演示的动作不能在解说中称已展示 |
| 95–107秒档案 | 改为Awaiting repair，但随后选中的是Investigating筛选 | 补录选Awaiting repair重新找到记录 |
| 108–128秒结尾 | 深色个人中心语言面板，无结尾卡或架构图 | 确定结尾剪辑；按实际画面更新旁白与时间轴 |
| 全片音频／字幕 | 音轨静音；无字幕轨 | 录制英文旁白、加入字幕，检查同步及演示屏幕上的可读性 |

原分镜和修改后的解说见[视频脚本](video-script.md)、[双语解说](video/narration-bilingual.md)。视频及相关素材属于团队交付；不根据本记录改写其他成员的历史分工。

## 市场来源复核

以下为公开资料比较，复核日期2026-11-14，不代表安装使用后的可靠性评测。

- [iFixit FixBot介绍](https://www.ifixit.com/News/114700/introducing-fixbot)：图片、维修资料与分步辅助；与报告描述一致。
- [Frontdoor官方支持](https://www.frontdoor.com/member-support)：实时专家视频、通话笔记与本地专业人员转介。
- [Google Lens官方说明](https://support.google.com/websearch/answer/1325808?hl=en)：物体、相似图、相关网站与AI概览。
- [FixIt Lens工程参考](https://github.com/rakexhs/fixit-lens)：图像输入、检索、安全门和引用流程。报告未把它计作前三款市场应用。

## 后续验收事项

- [ ] 按`docs/validation.md`补Qwen逐次记录：实际commit、输入、语言、输出、每步原文／页码／chunk ID、耗时及异常。现有视频与历史摘要不能替代这些记录。
- [ ] 补真实设备与真机验收：设备型号、相机／相册、网络错误、分享／通知及OAuth。不要用mock和外观照替代真实故障验收。
- [ ] 后续按团队安排处理视频补拍、配音、字幕、最终播放和隐私检查；本次不修改视频。
- [ ] 更新`docs/assets/snapfix-hero.png`与`docs/assets/screenshots/diagnosis.jpg`中的旧洗衣机E24界面；README及报告现已标明该画面过期，勿作当前功能证据。
- [ ] 填写真实学号；确认最终个人贡献，补充GitHub以外的工作；每人独立提交课程Peer Review Form。
- [ ] 与团队确认19号展示的讲解、现场演示、视频播放及设备／网络备用安排。仓库文件无法代替团队作出这些决定。

### 待执行的在线记录

| 实际执行时间 | 代码commit | provider／模型 | 输入／语言 | 实际结果／步骤数 | 引用原文／页码／chunk ID | 耗时／异常 | 证据文件 |
|---|---|---|---|---|---|---|---|
| 待执行 | 待填 | 待填 | 待填 | 待验证 | 待验证 | 待测量 | 待保存（不含密钥／令牌） |
