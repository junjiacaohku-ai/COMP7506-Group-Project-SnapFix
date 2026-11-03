import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
import '../ui.dart';
import '../util/toast.dart';
import 'analyzing_page.dart';

class ErrorCodePage extends StatefulWidget {
  const ErrorCodePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ErrorCodePage> createState() => _ErrorCodePageState();
}

class _ErrorCodePageState extends State<ErrorCodePage> {
  final _brandController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
        ),
      ),
    );
    if (error != null && mounted) {
      showAppToast(context, error);
    }
  }

  void _fillExample() {
    setState(() {
      _brandController.text = 'Bosch';
      _codeController.text = 'E24';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错误码速查')),
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppPill(
                      label: '官方手册检索',
                      icon: Icons.menu_book_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '错误码，直接查。',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    '输入设备品牌和显示屏上的代码，\n无需拍照也能找到对应维修指引。',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _brandController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppColors.text, fontSize: 16),
                    decoration: const InputDecoration(
                      labelText: '设备品牌',
                      hintText: '例如 Bosch',
                      prefixIcon: Icon(Icons.factory_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入设备品牌' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codeController,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                    decoration: const InputDecoration(
                      labelText: '错误码',
                      hintText: '例如 E24',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入错误码' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: _fillExample,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 21,
                            ),
                            SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                '使用演示示例',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              'Bosch · E24',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: '查询维修指引',
                    icon: Icons.manage_search_rounded,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        color: AppColors.muted,
                        size: 16,
                      ),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '结果附手册来源，方便核对与报修',
                          style: TextStyle(
                            color: AppColors.secondary,
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
