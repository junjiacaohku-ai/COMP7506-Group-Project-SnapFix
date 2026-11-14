公开设备照片包（当前集成版）

现有14个JPG原图文件，SHA256去重后13张唯一照片（extra-17.jpg与public-09.jpg重复）。每张照片的来源页、作者、许可和校验值见sources.json；再分发须保留署名，CC BY-SA图片及衍生物保留对应许可。

public-01/02及extra-3：TP-Link TL-WR740N的不同视角。语料包含TL-WR740N V5和TL-WR940N手册，仍需确认实物硬件修订号，不能自动视作同型号匹配。
public-03/04及extra-8：BILLY外观图，不能证明商品编号、组装问题或缺件。
public-05/06/07及extra-14：微波炉外观，不证明不加热或内部故障。
public-08/09、extra-7/17：洗衣机外观，不用于Bosch洗碗机E24场景。public-09本身较暗，可检查重拍提醒。

router-ai-quality-variants.png：以public-01为参考，ImageGen生成的暗图／模糊双面板示意；原作者Hayden Schiff，原图CC BY 4.0，衍生图同许可并注明AI编辑。它不是确定性曝光／模糊处理，也不是两个独立实拍样本，不纳入13张原图或26张处理图统计。

本素材包没有已核实的真实故障图，也没有添加红灯、错误码或设备损坏。当前后端实际读取像素检查质量；只有mock模式按明确的演示文件名或已支持的原始演示图片SHA256选择场景，在线模式由视觉模型提取信息。文件名不能作为实际故障或型号识别证据。

离线文件与来源校验：在server/运行python experiments/validate_data_assets.py。
