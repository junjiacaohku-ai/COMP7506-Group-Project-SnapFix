import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../util/toast.dart';
import 'result_page.dart';

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
      setState(() => _error = '加载失败,请检查后端连接');
    }
  }

  Future<void> _open(Session session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(api: widget.api, session: session),
      ),
    );
    reload();
  }

  Future<bool> _confirmDelete(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条记录?'),
        content: Text(
          '${deviceCategoryLabel(session.deviceCategory)}的诊断记录将被删除。',
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
      if (mounted) showAppToast(context, '删除失败,请稍后重试');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('档案')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final sessions = _sessions;
    if (_error != null) {
      return _CenteredHint(
        icon: Icons.cloud_off_outlined,
        text: _error!,
        action: TextButton(onPressed: reload, child: const Text('重试')),
      );
    }
    if (sessions == null) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    if (sessions.isEmpty) {
      return const _CenteredHint(
        icon: Icons.photo_camera_outlined,
        text: '还没有诊断记录,去拍第一张吧',
      );
    }
    return RefreshIndicator(
      color: AppColors.amber,
      backgroundColor: AppColors.card,
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
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
                color: AppColors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.onAmber,
                size: 28,
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0x26F5A623),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  deviceCategoryIcon(session.deviceCategory),
                  color: AppColors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceCategoryLabel(session.deviceCategory),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDateTime(session.createdAt),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: decision.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: decision.color.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  decision.label,
                  style: TextStyle(color: decision.color, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondary, size: 44),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(color: AppColors.secondary, fontSize: 16),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
