import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import 'error_code_page.dart';
import 'result_page.dart';
import 'scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.user,
    required this.onProfileTap,
    required this.onHistoryTap,
  });

  final ApiClient api;
  final AuthUser user;
  final VoidCallback onProfileTap;
  final VoidCallback onHistoryTap;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _offline = false;
  HealthInfo? _health;
  List<Session>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.api.health(),
        widget.api.listSessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _offline = false;
        _health = results[0] as HealthInfo;
        _sessions = results[1] as List<Session>;
      });
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  Future<void> _openScan() async {
    await Navigator.of(context)
        .push(AppPageRoute(child: ScanPage(api: widget.api)));
    _load();
  }

  void _openErrorCode() {
    Navigator.of(context)
        .push(AppPageRoute(child: ErrorCodePage(api: widget.api)));
  }

  Future<void> _openSession(Session session) async {
    await Navigator.of(context).push(
      AppPageRoute(
        child: ResultPage(api: widget.api, session: session),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            color: context.colors.primary,
            backgroundColor: context.colors.surfaceRaised,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
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
                  _OfflineBanner(onRetry: _load),
                ],
                const SizedBox(height: 28),
                Text(
                  context.tr('你好，{name}', {'name': widget.user.name}),
                  style: TextStyle(
                    color: context.colors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('你的维修工作台'),
                  style: TextStyle(
                    color: context.colors.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('诊断新故障，或继续上一次的维修。'),
                  style: TextStyle(
                    color: context.colors.secondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                _ScanHero(
                  online: !_offline,
                  demo: _health?.mock ?? false,
                  onTap: _openScan,
                ),
                const SizedBox(height: 12),
                _QuickAction(
                  icon: Icons.tag_rounded,
                  title: '错误码速查',
                  subtitle: '无需拍照，直接检索',
                  onTap: _openErrorCode,
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('最近诊断'),
                        style: TextStyle(
                          color: context.colors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_sessions?.isNotEmpty ?? false)
                      TextButton(
                        onPressed: widget.onHistoryTap,
                        child: Text(context.tr('查看全部')),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_sessions == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_sessions!.isEmpty)
                  SurfaceCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: context.colors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            context.tr('完成第一次诊断后，维修进度和手册引用会集中在这里。'),
                            style: TextStyle(
                              color: context.colors.secondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final session in _sessions!.take(2)) ...[
                    _RecentSessionCard(
                      session: session,
                      onTap: () => _openSession(session),
                    ),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 14),
                SurfaceCard(
                  color: context.colors.primary.withValues(alpha: 0.06),
                  borderColor: context.colors.primary.withValues(alpha: 0.16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.health_and_safety_outlined,
                        color: context.colors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('先安全，后维修。拆机或接触内部元件前务必断电。'),
                          style: TextStyle(
                            color: context.colors.secondary,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({
    required this.online,
    required this.demo,
    required this.onTap,
  });

  final bool online;
  final bool demo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 206,
          decoration: BoxDecoration(
            gradient: context.colors.heroGradient,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 16,
                child: AppPill(
                  label: context.tr('拍照诊断'),
                  icon: Icons.photo_camera_outlined,
                ),
              ),
              Positioned(
                top: 23,
                right: 18,
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !online
                            ? context.colors.red
                            : demo
                            ? context.colors.amber
                            : context.colors.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr(
                        !online
                            ? '离线'
                            : demo
                            ? '演示模式'
                            : '已就绪',
                      ),
                      style: TextStyle(
                        color: context.colors.secondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 18,
                right: 150,
                top: 56,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      context.tr('拍摄故障部位'),
                      style: TextStyle(
                        color: context.colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr('拍照或从相册选择'),
                      style: TextStyle(
                        color: context.colors.secondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: context.colors.primary,
                      size: 24,
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 12,
                bottom: 0,
                child: ScanFrame(size: 142),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: context.colors.primary, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(title),
                      style: TextStyle(
                        color: context.colors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(subtitle),
                      style: TextStyle(
                        color: context.colors.secondary,
                        fontSize: 10,
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

class _RecentSessionCard extends StatelessWidget {
  const _RecentSessionCard({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = session.steps
        .where((step) => step.feedback == 'done')
        .length;
    final progress = session.steps.isEmpty
        ? 0.0
        : completed / session.steps.length;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      deviceCategoryIcon(session.deviceCategory),
                      color: context.colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            deviceCategoryLabel(session.deviceCategory),
                          ),
                          style: TextStyle(
                            color: context.colors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (session.brand?.isNotEmpty ?? false)
                              session.brand,
                            if (session.errorCode?.isNotEmpty ?? false)
                              session.errorCode,
                          ].join(' · '),
                          style: TextStyle(
                            color: context.colors.secondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (session.safetyRefused ||
                  session.decision == 'professional' ||
                  session.steps.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr('需要专业维修'),
                    style: TextStyle(
                      color: context.colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: context.colors.surfaceRaised,
                  ),
                ),
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.tr('{done}/{total} 个步骤已完成', {
                      'done': completed,
                      'total': session.steps.length,
                    }),
                    style: TextStyle(
                      color: context.colors.secondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
