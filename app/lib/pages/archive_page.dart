import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';
import 'result_page.dart';
import 'scan_page.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ArchivePage> createState() => ArchivePageState();
}

class ArchivePageState extends State<ArchivePage> {
  List<Session>? _sessions;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final sessions = await widget.api.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '加载失败，请检查后端连接');
    }
  }

  Future<void> _open(Session session) async {
    await Navigator.of(context).push(
      AppPageRoute(
        child: ResultPage(api: widget.api, session: session),
      ),
    );
    reload();
  }

  Future<void> _startDiagnosis() async {
    await Navigator.of(context)
        .push(AppPageRoute(child: ScanPage(api: widget.api)));
    reload();
  }

  Future<bool> _confirmDelete(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(
          '${deviceCategoryLabel(session.deviceCategory)}的诊断记录将被永久删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await widget.api.deleteSession(session.id);
      return true;
    } catch (_) {
      if (mounted) showAppToast(context, '删除失败，请稍后重试');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '诊断档案',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '每一次维修，都有据可查',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sessions != null && sessions.isNotEmpty)
                      AppPill(label: '${sessions.length} 条记录'),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final sessions = _sessions;
    if (_error != null) {
      return _CenteredHint(
        icon: Icons.cloud_off_outlined,
        title: '暂时无法加载',
        text: _error!,
        action: TextButton(onPressed: reload, child: const Text('重新连接')),
      );
    }
    if (sessions == null) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (sessions.isEmpty) {
      return _CenteredHint(
        icon: Icons.inventory_2_outlined,
        title: '还没有诊断档案',
        text: '拍下第一个故障，诊断报告会保存在这里',
        action: SizedBox(
          width: 220,
          child: GradientButton(
            label: '开始第一次诊断',
            icon: Icons.photo_camera_outlined,
            height: 52,
            onPressed: _startDiagnosis,
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final session = sessions[index];
          return Dismissible(
            key: ValueKey(session.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(session),
            onDismissed: (_) {
              setState(
                () => _sessions = [
                  for (final s in _sessions!)
                    if (s.id != session.id) s,
                ],
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            child: _SessionTile(session: session, onTap: () => _open(session)),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decision = decisionStyle(session.decision);
    final brandModel = [
      if (session.brand?.isNotEmpty ?? false) session.brand,
      if (session.model?.isNotEmpty ?? false) session.model,
    ].join(' ');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      deviceCategoryIcon(session.deviceCategory),
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deviceCategoryLabel(session.deviceCategory),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (brandModel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            brandModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 21,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDateTime(session.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  AppPill(
                    label: decision.label,
                    icon: decision.icon,
                    color: decision.color,
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

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(icon, color: AppColors.primary, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}
