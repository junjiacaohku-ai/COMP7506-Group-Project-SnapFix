"""Mock 确定性演示数据:覆盖 PRD §12 的 6 个验收场景。

mock 模式(无 GEMINI_API_KEY)时,拍照诊断按以下优先级路由到场景:
文件名关键词 → 演示照片均值色指纹(经相册重编码仍稳定) → 内容哈希轮换。
同一张图永远得到同一结果。
"""
from __future__ import annotations

import hashlib
import io

from PIL import Image

MOCK_SCENARIOS: dict[str, dict] = {
    "router": {
        "device_category": "router", "brand": "TP-Link", "model": "Archer 系列",
        "error_code": None,
        "decision": "diy",
        "decision_reason": "Internet 红灯多为接线或拨号问题,非破坏性排查,约 10 分钟。",
        "steps": [
            ("检查光猫与路由器之间的 WAN 网线两端是否插紧,可拔出重插。",
             "TP-Link 无线路由器快速指南", "§4.1 Internet 红灯排查"),
            ("先后重启光猫与路由器,间隔 30 秒先后通电,观察 Internet 灯。",
             "TP-Link 无线路由器快速指南", "§4.1 Internet 红灯排查"),
            ("浏览器访问 192.168.0.1 进入 WAN 设置,确认上网方式与运营商一致(PPPoE 需账号密码)。",
             "TP-Link 无线路由器快速指南", "§4.2 登录管理页检查拨号"),
            ("若仍红灯,用电脑直连光猫测试:直连也断网则为运营商问题,致电宽带客服。",
             "TP-Link 无线路由器快速指南", "§4.3 确认宽带是否欠费或故障"),
        ],
    },
    "washer": {
        "device_category": "washing_machine", "brand": "Bosch", "model": None,
        "error_code": "E24",
        "decision": "diy",
        "decision_reason": "排水泵滤网堵塞,非破坏性操作,工具只需一枚硬币,约 15 分钟。",
        "steps": [
            ("断电并关闭水龙头,在机器右下角找到排水泵检修口,垫毛巾接残水。",
             "Bosch 滚筒洗衣机用户手册", "§7.2 排水泵检修口位置"),
            ("用硬币逆时针旋开滤网盖,取出滤网清除硬币、纽扣等异物。",
             "Bosch 滚筒洗衣机用户手册", "§7.3 清理排水泵滤网"),
            ("手转叶轮确认顺畅,装回滤网拧紧,通电试运行单脱水程序。",
             "Bosch 滚筒洗衣机用户手册", "§7.4 复位与测试"),
        ],
    },
    "ikea": {
        "device_category": "ikea_furniture", "brand": "IKEA", "model": "BILLY 书架",
        "error_code": None,
        "decision": "diy",
        "decision_reason": "板式家具组装,工具只需螺丝刀与锤子,约 40 分钟,两人更佳。",
        "steps": [
            ("按清单清点板材与五金,缺件可凭小票到 IKEA 门店免费领取。",
             "IKEA BILLY 书架组装说明书", "§1 工具与清点"),
            ("木销敲入侧板,对准顶底板,用偏心轮连接件锁紧,先确认框架方正再锁死。",
             "IKEA BILLY 书架组装说明书", "§2 框架组装"),
            ("滑入背板并敲钉固定,用底部可调脚调平柜体。",
             "IKEA BILLY 书架组装说明书", "§3 背板与调平"),
            ("重要:必须用随附固定件将书架固定在墙上,防倾倒。",
             "IKEA BILLY 书架组装说明书", "§4 防倾倒固定(重要)"),
        ],
    },
    "microwave": {
        "device_category": "microwave", "brand": None, "model": None,
        "error_code": None,
        "decision": "refused",
        "decision_reason": "微波炉内部高压电容断电后仍可致命,属于高危类目,不提供任何拆解步骤。",
        "steps": [],
        "safety_refused": True,
    },
    "water_heater": {
        "device_category": "water_heater", "brand": None, "model": None,
        "error_code": None,
        "decision": "landlord",
        "decision_reason": "热水器属房东配置,内部维修责任在房东;可先自行尝试复位键。",
        "steps": [
            ("检查漏电保护插头是否跳闸,按下插头上的复位按钮。",
             "储水式电热水器使用与保养手册", "§3.1 无热水排查"),
            ("若电源灯亮但不加热,待内胆冷却后按侧盖内温控复位键。",
             "储水式电热水器使用与保养手册", "§3.1 无热水排查"),
            ("若仍无热水,内部加热管/温控故障责任通常在房东,拍照记录并联系房东。",
             "储水式电热水器使用与保养手册", "§5 责任提示"),
        ],
    },
}

_KEYWORDS = {
    "router": ["router", "tplink", "路由器", "wifi"],
    "washer": ["washer", "washing", "e24", "bosch", "洗衣机"],
    "ikea": ["ikea", "billy", "shelf", "书架", "家具"],
    "microwave": ["microwave", "微波炉"],
    "water_heater": ["heater", "water", "热水器"],
}


def route(filename: str | None, image_bytes: bytes) -> dict:
    """文件名关键词优先;其次演示照片均值色指纹;最后内容哈希确定性轮换。"""
    name = (filename or "").lower()
    for key, words in _KEYWORDS.items():
        if any(w in name for w in words):
            return MOCK_SCENARIOS[key]
    matched = _match_photo(image_bytes)
    if matched:
        return MOCK_SCENARIOS[matched]
    digest = int(hashlib.md5(image_bytes).hexdigest(), 16)
    safe = ["router", "washer", "ikea", "water_heater"]  # 拒答场景不进哈希轮换
    return MOCK_SCENARIOS[safe[digest % len(safe)]]


# demo-photos/ 四张合成图的均值色指纹(Pillow 重采样 64x64 后实测)
_PHOTO_FINGERPRINTS = {
    "ikea": (231, 226, 214),
    "microwave": (158, 158, 163),
    "router": (183, 184, 190),
    "washer": (208, 208, 213),
}

_MATCH_THRESHOLD = 40  # 指纹最近距离上限,超出视为未知照片


def _match_photo(image_bytes: bytes) -> str | None:
    try:
        im = Image.open(io.BytesIO(image_bytes)).convert("RGB").resize((64, 64))
    except Exception:
        return None
    data = list(im.getdata())
    n = len(data)
    mean = tuple(sum(p[i] for p in data) // n for i in range(3))
    best, best_dist = None, None
    for key, fp in _PHOTO_FINGERPRINTS.items():
        dist = sum((mean[i] - fp[i]) ** 2 for i in range(3)) ** 0.5
        if best_dist is None or dist < best_dist:
            best, best_dist = key, dist
    return best if best_dist is not None and best_dist < _MATCH_THRESHOLD else None
