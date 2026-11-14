import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';
import 'analyzing_page.dart';
import 'toolbox_page.dart';

class ErrorCodePage extends StatefulWidget {
  const ErrorCodePage({super.key, required this.api, this.initialBrand});

  final ApiClient api;
  final String? initialBrand;

  @override
  State<ErrorCodePage> createState() => _ErrorCodePageState();
}

class _ErrorCodePageState extends State<ErrorCodePage> {
  late final TextEditingController _brandController;
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.initialBrand ?? '');
  }

  @override
  void dispose() {
    _brandController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final brand = _brandController.text.trim();
    final code = _codeController.text.trim();
    final error = await Navigator.of(context).push<String>(
      AppPageRoute(
        child: AnalyzingPage(
          api: widget.api,
          start: () => widget.api.diagnoseManual(brand, code),
          isPhotoDiagnosis: false,
        ),
      ),
    );
    if (error != null && mounted) {
      showAppToast(context, context.tr(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('错误码速查'))),
      body: AppBackground(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppPill(
                      label: context.tr('官方手册检索'),
                      icon: Icons.menu_book_outlined,
                      color: context.colors.accent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('错误码，直接查。'),
                    style: TextStyle(
                      color: context.colors.text,
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.tr('输入设备品牌和显示屏上的代码，\n无需拍照也能找到对应维修指引。'),
                    style: TextStyle(
                      color: context.colors.secondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _brandController,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: context.colors.text, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: context.tr('设备品牌'),
                      hintText: context.tr('例如 Bosch'),
                      prefixIcon: Icon(Icons.factory_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('请输入设备品牌')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      color: context.colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('错误码'),
                      hintText: context.tr('例如 E24'),
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('请输入错误码')
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: context.tr('查询维修指引'),
                    icon: Icons.manage_search_rounded,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(AppPageRoute(child: ToolboxPage(api: widget.api))),
                    icon: const Icon(Icons.menu_book_outlined, size: 19),
                    label: Text(context.tr('浏览手册库')),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        color: context.colors.muted,
                        size: 16,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          context.tr('结果附手册来源，方便核对与报修'),
                          style: TextStyle(
                            color: context.colors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
