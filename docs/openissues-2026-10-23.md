# Open Issues — 2026-10-23

## 1. iOS 26.3 模拟器不渲染瞬时 toast(待真机复核)

**现象**:所有"出现时伴随挂起异步工作(Timer/动画控制器)的短驻留 UI"
在 iPhone 17 Pro + iOS 26.3 模拟器上完全不上屏;截图(两种工具)与语义树中
均无该节点,但日志证实 builder 执行、路由按定时器精确 pop。

**已验证不渲染的实现**(均在同一模拟器上):
- `showDialog` + 自定义卡片/AlertDialog + Timer 自动关
- `showDialog` + AnimationController 自动关(build→pop 精确 1811ms)
- `showModalBottomSheet` + 自动关闭
- `MaterialApp.builder` 页面树内 ToastHost(ValueNotifier 驱动)
- 页面级 Stack + ValueNotifier overlay
- 标准 `ScaffoldMessenger.showSnackBar`(当前实现,2026-10-23 模拟器重启后复测)

**对照(正常渲染)**:需用户手动关闭的 AlertDialog(删除确认)、
`showModalBottomSheet`(报修信息)、异步 setState 驱动的页面更新、
AnalyzingPage 的持续旋转/脉冲动画。

**2026-10-23 决定性实验**(重启后的模拟器,mock 后端在线):
报修 sheet → 点"复制" → 剪贴板确认写入(`xcrun simctl pbpaste` 读到新内容,
证明 `showAppToast` 已调用)→ sheet 关闭后立即截图,SnackBar 不上屏。

**结论**:模拟器/Impeller 渲染层怪癖,非应用逻辑 bug。当前实现保留标准
SnackBar(`app/lib/util/toast.dart`)。**待办:在真机上跑一遍错误反馈与复制
链路确认 toast 正常**;若真机也不显示再 reopen。

## 2. 联调环境注意事项(非产品缺陷)

- `flutter run` 在该模拟器上启动后约 1 分钟内报 "Lost connection to device"
  并退出,但 app 本体继续在模拟器上运行;可用
  `xcrun simctl launch/terminate <udid> hk.snapfix.snapfixSolo` 直接操控 app。
- 杀掉后端后,app 内 `http.Client` 复用的 keep-alive 连接会让下一次请求
  挂起至 30s 超时(而非立即 connection refused);验证离线错误路径时需先
  重启 app 再断后端。
- 档案列表来自后端 SQLite(`/api/sessions`),离线时显示加载失败态属预期。

## 3. 测试基建缺口

server 与 app 目前均无自动化测试套件(venv 无 pytest,无 tests/ 目录)。
本次联调以 API 实证代替:健康检查、4 场景 `/api/analyze/image`、
`/api/sessions`、`/api/sessions/:id/report`、步骤反馈均 200 验证通过。
建议后续补:安全门分类单测、mock 场景契约测试、app widget 测试。
