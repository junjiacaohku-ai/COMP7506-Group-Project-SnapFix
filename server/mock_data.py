"""Mock 确定性演示数据:照片演示与手动错误码演示分开路由。

mock 模式(无可用真实模型配置)时,只通过文件名关键词或演示照片指纹匹配场景。
未知图片明确拒绝,不生成无关结果。
"""
from __future__ import annotations

from hashlib import sha256

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
        "decision": "refused",
        "decision_reason": "电热水器内部同时涉及水路和市电，请停止自行检修并联系专业人员。",
        "steps": [],
        "safety_refused": True,
    },
}

_KEYWORDS = {
    "router": ["router", "tplink", "路由器", "wifi"],
    "ikea": ["ikea", "billy", "shelf", "书架", "家具"],
    "microwave": ["microwave", "微波炉"],
    "water_heater": ["heater", "water", "热水器"],
}


def route(filename: str | None, image_bytes: bytes) -> dict | None:
    """只匹配明确的演示场景；未知图片不生成无关诊断。"""
    name = (filename or "").lower()
    for key, words in _KEYWORDS.items():
        if any(w in name for w in words):
            return MOCK_SCENARIOS[key]
    matched = _match_photo(image_bytes)
    return MOCK_SCENARIOS[matched] if matched else None


# Exact SHA-256 hashes of the supported original demo-photos files. Colour
# similarity is not evidence of identity: unrelated pale/grey images must not
# receive a deterministic appliance diagnosis. Renamed original files work;
# edited/re-encoded copies require an explicit scenario filename in mock mode.
_PHOTO_HASHES = {
    "d371fcfee2e4ee25d073a936e443270bcfeb962a11e8a714b0bcc7fea3e8ad1a": "ikea",
    "5b0c273158ccde0c124a927b5ed9bdc29aa8ebbd2fbde1f89db8fe429947ef61": "microwave",
    "cf83801c9950325f08e60493b09be10317c2849b93b5d3b8e57097d577dd8200": "router",
}


def _match_photo(image_bytes: bytes) -> str | None:
    return _PHOTO_HASHES.get(sha256(image_bytes).hexdigest())
