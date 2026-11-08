import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../ui.dart';
import 'error_code_page.dart';

class ToolboxPage extends StatefulWidget {
  const ToolboxPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ToolboxPage> createState() => ToolboxPageState();
}

class ToolboxPageState extends State<ToolboxPage> {
  List<ManualInfo>? _manuals;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final manuals = await widget.api.manuals();
      if (!mounted) return;
      setState(() {
        _manuals = manuals;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '手册库暂时无法加载');
    }
  }

  void _showSafetyGuide() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.health_and_safety_outlined,
          color: dialogContext.colors.primary,
          size: 32,
        ),
        title: Text(dialogContext.tr('维修前安全检查')),
        content: Text(
          '${dialogContext.tr('• 先断电，再拆面板或接触设备内部。')}\n\n'
          '${dialogContext.tr('• 微波炉高压电容、燃气设备和带电维修应交由专业人员。')}\n\n'
          '${dialogContext.tr('• 出现焦味、冒烟、火花或异常发热时立即停止操作。')}\n\n'
          '${dialogContext.tr('• 保留设备型号和错误码，便于房东或维修师傅核对。')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('知道了')),
          ),
        ],
      ),
    );
  }

  void _openManual(ManualInfo manual) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: sheetContext.colors.primary,
                  size: 30,
                ),
                const SizedBox(height: 14),
                Text(
                  manual.title,
                  style: TextStyle(
                    color: sheetContext.colors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${manual.brand ?? ''} · ${sheetContext.tr(deviceCategoryLabel(manual.category))}',
                  style: TextStyle(
                    color: sheetContext.colors.secondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  sheetContext.tr('来源章节与原文摘要'),
                  style: TextStyle(
                    color: sheetContext.colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: manual.sections.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final section = manual.sections[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sheetContext.colors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetContext.colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.section,
                              style: TextStyle(
                                color: sheetContext.colors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.text,
                              style: TextStyle(
                                color: sheetContext.colors.text,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: '查询相关维修指引',
                  icon: Icons.manage_search_rounded,
                  height: 50,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      AppPageRoute(
                        child: ErrorCodePage(
                          api: widget.api,
                          initialBrand: manual.brand,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manuals = (_manuals ?? const <ManualInfo>[]).where((manual) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          manual.title.toLowerCase().contains(query) ||
          (manual.brand ?? '').toLowerCase().contains(query) ||
          deviceCategoryLabel(manual.category).contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('手册资料库'))),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr('搜索手册'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  onTap: _showSafetyGuide,
                  leading: Icon(
                    Icons.health_and_safety_outlined,
                    color: context.colors.primary,
                  ),
                  title: Text(context.tr('维修前安全检查')),
                  subtitle: Text(context.tr('断电、高危场景与停止操作信号')),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.muted,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (_error != null)
                SurfaceCard(
                  child: Column(
                    children: [
                      Text(context.tr(_error!)),
                      TextButton(
                        onPressed: reload,
                        child: Text(context.tr('重试')),
                      ),
                    ],
                  ),
                )
              else if (_manuals == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (manuals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(child: Text(context.tr('暂无匹配手册'))),
                )
              else
                for (final manual in manuals) ...[
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onTap: () => _openManual(manual),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          deviceCategoryIcon(manual.category),
                          color: context.colors.primary,
                          size: 21,
                        ),
                      ),
                      title: Text(
                        manual.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${manual.brand ?? ''} · ${context.tr(deviceCategoryLabel(manual.category))}',
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
