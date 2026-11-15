import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';

class FeedbackHistoryPage extends StatefulWidget {
  const FeedbackHistoryPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<FeedbackHistoryPage> createState() => _FeedbackHistoryPageState();
}

class _FeedbackHistoryPageState extends State<FeedbackHistoryPage> {
  List<DiagnosisFeedback>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.listDiagnosisFeedback();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '反馈记录暂时无法加载');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('用户反馈历史'))),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            color: context.colors.primary,
            backgroundColor: context.colors.surfaceRaised,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _FeedbackHint(
        icon: Icons.cloud_off_outlined,
        title: '暂时无法加载',
        text: _error!,
        action: TextButton(onPressed: _load, child: Text(context.tr('重试'))),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const _FeedbackHint(
        icon: Icons.feedback_outlined,
        title: '暂无反馈记录',
        text: '提交超时反馈后，会在这里留下记录。',
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          context.tr('查看已提交的超时与诊断反馈'),
          style: TextStyle(color: context.colors.secondary, fontSize: 13),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < items.length; index++) ...[
          _FeedbackCard(item: items[index]),
          if (index != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});

  final DiagnosisFeedback item;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.feedback_outlined,
                  color: context.colors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(diagnosisFeedbackEventLabel(item.event)),
                      style: TextStyle(
                        color: context.colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatRelativeDateTime(
                        item.createdAt,
                        Localizations.localeOf(context).languageCode,
                      ),
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FeedbackChip(
                icon: Icons.language_rounded,
                label: item.language == 'zh' ? '中文' : 'English',
              ),
              if (item.platform != null && item.platform!.isNotEmpty)
                _FeedbackChip(
                  icon: Icons.devices_outlined,
                  label: item.platform!,
                ),
              _FeedbackChip(
                icon: Icons.timer_outlined,
                label: context.tr('{seconds} 秒超时', {
                  'seconds': item.elapsedSeconds,
                }),
              ),
            ],
          ),
          if (item.error != null && item.error!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceRaised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Text(
                context.tr(item.error!),
                style: TextStyle(
                  color: context.colors.secondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.primary, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.colors.secondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackHint extends StatelessWidget {
  const _FeedbackHint({
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 80),
        Container(
          width: 82,
          height: 82,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Icon(icon, color: context.colors.primary, size: 34),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr(title),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(text),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.secondary,
            fontSize: 13,
            height: 1.55,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          Center(child: action!),
        ],
      ],
    );
  }
}
