import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import 'result_page.dart';

class AnalyzingPage extends StatefulWidget {
  const AnalyzingPage({super.key, required this.api, required this.start});

  final ApiClient api;
  final Future<Session> Function() start;

  @override
  State<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends State<AnalyzingPage>
    with TickerProviderStateMixin {
  static const _stages = [
    (icon: Icons.document_scanner_outlined, label: '识别中', hint: '辨认设备与错误码'),
    (icon: Icons.menu_book_outlined, label: '查手册', hint: '检索官方维修手册'),
    (icon: Icons.shield_outlined, label: '安全评估', hint: '排查触电、燃气等风险'),
    (icon: Icons.format_list_numbered, label: '生成步骤', hint: '整理分步维修指引'),
  ];
  static const _stageDuration = Duration(milliseconds: 1000);

  late final AnimationController _spin;
  late final AnimationController _pulse;
  int _activeStage = 0;
  int _doneCount = 0;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _run();
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    Session? session;
    Object? error;
    final request = () async {
      try {
        session = await widget.start();
      } catch (e) {
        error = e;
      }
    }();

    for (var i = 0; i < _stages.length; i++) {
      if (!mounted) return;
      setState(() => _activeStage = i);
      await Future<void>.delayed(_stageDuration);
      if (!mounted) return;
      setState(() => _doneCount = i + 1);
    }

    await request;
    if (!mounted) return;

    final result = session;
    final failure = error;
    if (result != null) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultPage(api: widget.api, session: result),
        ),
      );
    } else if (failure is ApiException && failure.isQualityError) {
      _showQualityDialog(failure.message);
    } else {
      Navigator.of(context)
          .pop(failure is ApiException ? failure.message : '网络异常,请稍后重试');
    }
  }

  void _showQualityDialog(String detail) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.no_photography_outlined,
          color: AppColors.amber,
          size: 36,
        ),
        title: const Text('照片不合格'),
        content: Text(detail, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
            child: const Text('重新拍摄'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stages[_activeStage.clamp(0, _stages.length - 1)];
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
            child: Column(
              children: [
                const Spacer(),
                _buildSpinner(stage.icon),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(
                    stage.hint,
                    key: ValueKey(_activeStage),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Spacer(),
                _buildStageList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpinner(IconData icon) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x14F5A623),
                border: Border.all(color: const Color(0x33F5A623)),
              ),
            ),
          ),
          RotationTransition(
            turns: _spin,
            child: SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: 0.72,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
          ),
          Icon(icon, size: 52, color: AppColors.amber),
        ],
      ),
    );
  }

  Widget _buildStageList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _stages.length; i++) ...[
            _StageRow(
              icon: _stages[i].icon,
              label: _stages[i].label,
              state: i < _doneCount
                  ? _StageState.done
                  : i == _activeStage
                  ? _StageState.active
                  : _StageState.pending,
            ),
            if (i < _stages.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

enum _StageState { pending, active, done }

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.icon,
    required this.label,
    required this.state,
  });

  final IconData icon;
  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StageState.active;
    final done = state == _StageState.done;
    final color = done
        ? AppColors.green
        : active
        ? AppColors.amber
        : AppColors.secondary;
    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: done
                ? const _StageBadge(
                    key: ValueKey('done'),
                    color: AppColors.green,
                    child: Icon(
                      Icons.check,
                      size: 20,
                      color: AppColors.onAmber,
                    ),
                  )
                : active
                ? const _StageBadge(
                    key: ValueKey('active'),
                    color: AppColors.amber,
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.onAmber,
                      ),
                    ),
                  )
                : _StageBadge(
                    key: const ValueKey('pending'),
                    color: AppColors.border,
                    child: Icon(icon, size: 18, color: AppColors.secondary),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: active || done ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const Spacer(),
        if (done)
          const Text(
            '完成',
            style: TextStyle(color: AppColors.green, fontSize: 13),
          ),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == AppColors.border ? AppColors.card : color,
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
