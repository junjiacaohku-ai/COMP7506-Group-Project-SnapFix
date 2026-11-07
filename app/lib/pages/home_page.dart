import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import 'error_code_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onProfileTap,
  });

  final ApiClient api;
  final AuthUser user;
  final VoidCallback onProfileTap;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    try {
      await widget.api.health();
      if (!mounted) return;
      setState(() => _offline = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _offline = true);
    }
  }

  void _openScan() {
    Navigator.of(context).push(AppPageRoute(child: ScanPage(api: widget.api)));
  }

  void _openErrorCode() {
    Navigator.of(context)
        .push(AppPageRoute(child: ErrorCodePage(api: widget.api)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              Row(
                children: [
                  const BrandMark(size: 40),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SnapFix',
                          style: TextStyle(
                            color: context.colors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          context.tr('随手修'),
                          style: TextStyle(
                            color: context.colors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: context.tr('打开个人资料'),
                    button: true,
                    child: InkWell(
                      onTap: widget.onProfileTap,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.primary.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.user.initials,
                              style: TextStyle(
                                color: context.colors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_offline) ...[
                const SizedBox(height: 16),
                _OfflineBanner(onRetry: _checkHealth),
              ],
              const SizedBox(height: 34),
              Text(
                context.tr('你好，{name}', {'name': widget.user.name}),
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('今天想修什么？'),
                style: TextStyle(
                  color: context.colors.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('拍照识别设备与错误码，\n获取带手册来源的维修建议。'),
                style: TextStyle(
                  color: context.colors.secondary,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 24),
              _ScanHero(online: !_offline, onTap: _openScan),
              const SizedBox(height: 14),
              Material(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: _openErrorCode,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.colors.accent.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.tag_rounded,
                            color: context.colors.accent,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('有错误码？直接查'),
                                style: TextStyle(
                                  color: context.colors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('跳过拍照，检索官方手册'),
                                style: TextStyle(
                                  color: context.colors.secondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: context.colors.muted,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _TrustItem(
                      icon: Icons.menu_book_outlined,
                      label: '手册溯源',
                    ),
                  ),
                  Expanded(
                    child: _TrustItem(
                      icon: Icons.shield_outlined,
                      label: '安全评估',
                    ),
                  ),
                  Expanded(
                    child: _TrustItem(
                      icon: Icons.lock_outline_rounded,
                      label: '隐私优先',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.online, required this.onTap});

  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          height: 282,
          decoration: BoxDecoration(
            gradient: context.colors.heroGradient,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 18,
                left: 18,
                child: AppPill(
                  label: context.tr('拍照诊断'),
                  icon: Icons.photo_camera_outlined,
                ),
              ),
              Positioned(
                top: 24,
                right: 20,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online
                            ? context.colors.green
                            : context.colors.red,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr(online ? '已就绪' : '离线'),
                      style: TextStyle(
                        color: context.colors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 34),
                  child: ScanFrame(size: 154),
                ),
              ),
              Positioned(
                left: 20,
                right: 16,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('拍摄故障部位'),
                            style: TextStyle(
                              color: context.colors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.tr('拍照或从相册选择'),
                            style: TextStyle(
                              color: context.colors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        color: context.colors.primaryDark,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: context.colors.muted, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr(label),
            style: TextStyle(
              color: context.colors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('诊断服务未连接'),
              style: TextStyle(color: context.colors.text, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(context.tr('重试'))),
        ],
      ),
    );
  }
}
