公开演示素材（当前集成版）

public/：14个JPG原图文件，按SHA256去重后13张；extra-17.jpg与public-09.jpg重复。作者、来源、许可和校验值见public/sources.json。照片是设备外观素材，不是已确认故障的样本，不能用于声称真实故障识别准确率。

quality/：从13张去重原图生成26张确定性的暗化／模糊PNG；参数、来源和许可见quality/manifest.json。当前检测行为和生成可重复性由server/tests/test_quality_variants.py验证。早期router-ai-quality-variants.png是AI示意图，不纳入定量检查。

alternatives/：另含3张同一Bosch洗碗机的不同视角照片，以及18个不同输入文件的来源清单。Bosch照片没有经过E24故障标注，mock图片模式应拒绝，不能由文件名生成E24诊断；S2使用手动输入Bosch／博世和E24／E:24。

当前后端需登录；mock演示和在线模型诊断须分别记录。当前26项替代素材用例（21次图片、5次手动输入，其中含拒绝用例）见alternatives/manifest.json，由server/tests/test_demo_alternatives.py在临时数据库和mock模式下复跑。系统复制、分享、摄像头和真实设备耗时仍需实机验证。

在server目录运行：
  python experiments/validate_data_assets.py
  python -m pytest tests/test_data_assets.py tests/test_demo_alternatives.py tests/test_quality_variants.py -q

校验命令不调用在线模型，也不修改原图或日常数据库。它核对本地文件、哈希、来源和语料审计记录，不证明来源网页当前仍可访问、完整许可证审查或真实故障诊断能力。
