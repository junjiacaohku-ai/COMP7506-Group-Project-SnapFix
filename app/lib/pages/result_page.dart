import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
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
      if (mounted) showAppToast(context, context.tr(e.message));
    } catch (_) {
      if (mounted) showAppToast(context, context.tr('网络异常，请稍后重试'));
    } finally {
      if (mounted) setState(() => _pendingStepId = null);
    }
  }

  void _showReport() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => ReportSheet(api: widget.api, sessionId: _session.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_session.safetyRefused) return _buildRefusedPage();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('诊断报告')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: AppPill(
                label: context.tr('手册溯源'),
                icon: Icons.verified_outlined,
              ),
            ),
          ),
        ],
      ),
      body: AppBackground(
        glow: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _DeviceCard(session: _session),
            const SizedBox(height: 14),
            _DecisionCard(session: _session),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('维修计划'),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                AppPill(
                  label: context.tr('{count} 个步骤', {
                    'count': _session.steps.length,
                  }),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('按顺序操作，可以随时标记完成进度'),
              style: const TextStyle(color: AppColors.secondary, fontSize: 12),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _session.steps.length; i++)
              _StepCard(
                step: _session.steps[i],
                isLast: i == _session.steps.length - 1,
                busy: _pendingStepId != null,
                onFeedback: (f) => _sendFeedback(_session.steps[i], f),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: GradientButton(
          onPressed: _showReport,
          icon: Icons.description_outlined,
          label: context.tr('生成双语报修信息'),
        ),
      ),
    );
  }

  Widget _buildRefusedPage() {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('安全评估'))),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.red.withValues(alpha: 0.09),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.gpp_maybe_outlined,
                    color: AppColors.red,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 24),
                AppPill(
                  label: context.tr('安全保护已触发'),
                  icon: Icons.shield_outlined,
                  color: AppColors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('这项维修不适合\n自行操作'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    _session.decisionReason,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('为避免人身与设备风险，SnapFix 不会提供\n高风险故障的自行维修步骤。'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.engineering_outlined, size: 22),
                  label: Text(context.tr('返回并寻求专业帮助')),
                ),
              ],
            ),
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
    return SurfaceCard(
      radius: 26,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  deviceCategoryIcon(session.deviceCategory),
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('识别结果'),
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(deviceCategoryLabel(session.deviceCategory)),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              AppPill(
                label: context.tr('诊断完成'),
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.green,
              ),
            ],
          ),
          if (brandModel.isNotEmpty ||
              session.errorCode?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      brandModel.isEmpty ? context.tr('设备型号未识别') : brandModel,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (session.errorCode?.isNotEmpty == true)
                    Text(
                      session.errorCode!,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              formatDateTime(session.createdAt),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.color.withValues(alpha: 0.13), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: style.color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: style.color.withValues(alpha: 0.12),
                ),
                child: Icon(style.icon, color: style.color, size: 24),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('维修建议'),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr(style.label),
                    style: TextStyle(
                      color: style.color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (session.decisionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              session.decisionReason,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: style.color.withValues(alpha: 0.8),
                size: 15,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr('已结合设备状态与安全规则'),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.isLast,
    required this.busy,
    required this.onFeedback,
  });

  final RepairStep step;
  final bool isLast;
  final bool busy;
  final ValueChanged<String> onFeedback;

  @override
  Widget build(BuildContext context) {
    final done = step.feedback == 'done';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.green
                      : AppColors.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: done ? AppColors.green : AppColors.primary,
                  ),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.background,
                      )
                    : Text(
                        '${step.idx}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    color: done
                        ? AppColors.green.withValues(alpha: 0.35)
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.green.withValues(alpha: 0.045)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: done
                        ? AppColors.green.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.content,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        height: 1.65,
                      ),
                    ),
                    if (step.citationManual.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      _Citation(
                        manual: step.citationManual,
                        section: step.citationSection,
                      ),
                    ],
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _FeedbackButton(
                          icon: Icons.check_rounded,
                          label: '完成',
                          selected: step.feedback == 'done',
                          selectedColor: AppColors.green,
                          enabled: !busy,
                          onTap: () => onFeedback('done'),
                        ),
                        const SizedBox(width: 7),
                        _FeedbackButton(
                          icon: Icons.arrow_forward_rounded,
                          label: '跳过',
                          selected: step.feedback == 'skipped',
                          selectedColor: AppColors.secondary,
                          enabled: !busy,
                          onTap: () => onFeedback('skipped'),
                        ),
                        const SizedBox(width: 7),
                        _FeedbackButton(
                          icon: Icons.close_rounded,
                          label: '没用',
                          selected: step.feedback == 'not_useful',
                          selectedColor: AppColors.red,
                          enabled: !busy,
                          onTap: () => onFeedback('not_useful'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Citation extends StatelessWidget {
  const _Citation({required this.manual, required this.section});

  final String manual;
  final String section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$manual${section.isEmpty ? '' : ' · $section'}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                height: 1.4,
              ),
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
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? selectedColor.withValues(alpha: 0.13)
              : AppColors.surfaceRaised,
          border: Border.all(
            color: selected ? selectedColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? selectedColor : AppColors.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              context.tr(label),
              style: TextStyle(
                color: selected ? selectedColor : AppColors.secondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
        height: MediaQuery.of(context).size.height * 0.66,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('报修信息'),
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.tr('一键复制给房东或维修师傅'),
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
              Container(
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.secondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  indicator: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '中文'),
                    Tab(text: 'English'),
                  ],
                ),
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
      setState(() => _error = '生成失败，请重试');
    }
  }

  Future<void> _copy() async {
    final content = _content;
    if (content == null) return;
    showAppToast(context, context.tr('已复制到剪贴板'));
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
              context.tr(_error!),
              style: const TextStyle(color: AppColors.secondary, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: Text(context.tr('重试'))),
          ],
        ),
      );
    }
    final content = _content;
    if (content == null) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
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
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.7,
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
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.copy_outlined, size: 19),
                  label: Text(context.tr('复制')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 19),
                  label: Text(context.tr('分享')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
