import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../util/toast.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.api, required this.session});

  final ApiClient api;
  final Session session;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Session _session;
  String? _pendingStepId;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _sendFeedback(RepairStep step, String feedback) async {
    if (_pendingStepId != null || step.feedback == feedback) return;
    setState(() => _pendingStepId = step.id);
    try {
      final updated = await widget.api.stepFeedback(
        _session.id,
        step.id,
        feedback,
      );
      if (!mounted) return;
      setState(() => _session = updated);
    } on ApiException catch (e) {
      if (mounted) showAppToast(context, e.message);
    } catch (_) {
      if (mounted) showAppToast(context, '网络异常,请稍后重试');
    } finally {
      if (mounted) setState(() => _pendingStepId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session.safetyRefused) return _buildRefusedPage();

    return Scaffold(
      appBar: AppBar(title: const Text('诊断结果')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _DeviceCard(session: _session),
          const SizedBox(height: 14),
          _DecisionCard(session: _session),
          const SizedBox(height: 20),
          const Text(
            '维修步骤',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final step in _session.steps) ...[
            _StepCard(
              step: step,
              busy: _pendingStepId != null,
              onFeedback: (f) => _sendFeedback(step, f),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.card,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            builder: (_) =>
                ReportSheet(api: widget.api, sessionId: _session.id),
          ),
          icon: const Icon(Icons.description_outlined, size: 22),
          label: const Text('生成报修信息'),
        ),
      ),
    );
  }

  Widget _buildRefusedPage() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x26FF6B6B),
                ),
                child: const Icon(
                  Icons.gpp_maybe_outlined,
                  color: AppColors.red,
                  size: 52,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '安全提示',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x66FF6B6B)),
                ),
                child: Text(
                  _session.decisionReason,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: AppColors.onAmber,
                ),
                icon: const Icon(Icons.engineering_outlined, size: 22),
                label: const Text('请咨询专业师傅'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final brandModel = [
      if (session.brand?.isNotEmpty ?? false) session.brand,
      if (session.model?.isNotEmpty ?? false) session.model,
    ].join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0x26F5A623),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                deviceCategoryIcon(session.deviceCategory),
                color: AppColors.amber,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceCategoryLabel(session.deviceCategory),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (brandModel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      brandModel,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (session.errorCode?.isNotEmpty ?? false)
                        '错误码 ${session.errorCode}',
                      formatDateTime(session.createdAt),
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final style = decisionStyle(session.decision);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, color: style.color, size: 24),
              const SizedBox(width: 8),
              Text(
                style.label,
                style: TextStyle(
                  color: style.color,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (session.decisionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              session.decisionReason,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.busy,
    required this.onFeedback,
  });

  final RepairStep step;
  final bool busy;
  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x26F5A623),
                border: Border.all(color: AppColors.amber),
              ),
              child: Text(
                '${step.idx}',
                style: const TextStyle(
                  color: AppColors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.content,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  if (step.citationManual.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _CitationChip(
                      manual: step.citationManual,
                      section: step.citationSection,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                _FeedbackButton(
                  icon: Icons.check,
                  tooltip: '完成',
                  selected: step.feedback == 'done',
                  selectedColor: AppColors.green,
                  enabled: !busy,
                  onTap: () => onFeedback('done'),
                ),
                const SizedBox(height: 6),
                _FeedbackButton(
                  icon: Icons.close,
                  tooltip: '没用',
                  selected: step.feedback == 'not_useful',
                  selectedColor: AppColors.red,
                  enabled: !busy,
                  onTap: () => onFeedback('not_useful'),
                ),
                const SizedBox(height: 6),
                _FeedbackButton(
                  icon: Icons.arrow_forward,
                  tooltip: '跳过',
                  selected: step.feedback == 'skipped',
                  selectedColor: AppColors.secondary,
                  enabled: !busy,
                  onTap: () => onFeedback('skipped'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.manual, required this.section});

  final String manual;
  final String section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 14,
            color: AppColors.amber,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$manual${section.isEmpty ? '' : ' · $section'}',
              style: const TextStyle(color: AppColors.amber, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.selectedColor,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color selectedColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? selectedColor : AppColors.card,
            border: Border.all(
              color: selected ? selectedColor : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AppColors.onAmber : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

class ReportSheet extends StatelessWidget {
  const ReportSheet({super.key, required this.api, required this.sessionId});

  final ApiClient api;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '报修信息',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const TabBar(
                labelColor: AppColors.amber,
                unselectedLabelColor: AppColors.secondary,
                indicatorColor: AppColors.amber,
                dividerColor: AppColors.border,
                tabs: [
                  Tab(text: '中文'),
                  Tab(text: 'English'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ReportPane(api: api, sessionId: sessionId, lang: 'zh'),
                    _ReportPane(api: api, sessionId: sessionId, lang: 'en'),
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

class _ReportPane extends StatefulWidget {
  const _ReportPane({
    required this.api,
    required this.sessionId,
    required this.lang,
  });

  final ApiClient api;
  final String sessionId;
  final String lang;

  @override
  State<_ReportPane> createState() => _ReportPaneState();
}

class _ReportPaneState extends State<_ReportPane>
    with AutomaticKeepAliveClientMixin {
  String? _content;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _content = null;
      _error = null;
    });
    try {
      final content = await widget.api.report(widget.sessionId, widget.lang);
      if (!mounted) return;
      setState(() => _content = content);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '生成失败,请重试');
    }
  }

  Future<void> _copy() async {
    final content = _content;
    if (content == null) return;
    showAppToast(context, '已复制到剪贴板');
    await Clipboard.setData(ClipboardData(text: content));
  }

  Future<void> _share() async {
    final content = _content;
    if (content == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: content,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.secondary, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final content = _content;
    if (content == null) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _copy,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  label: const Text('复制'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.amber,
                    side: const BorderSide(color: AppColors.amber),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 20),
                  label: const Text('分享'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
