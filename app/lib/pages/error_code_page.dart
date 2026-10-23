import 'package:flutter/material.dart';

import '../api.dart';
import '../theme.dart';
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
      MaterialPageRoute(
        builder: (_) => AnalyzingPage(
          api: widget.api,
          start: () => widget.api.diagnoseManual(brand, code),
        ),
      ),
    );
    if (error != null && mounted) {
      showAppToast(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('错误码速查')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '输入设备品牌与显示屏上的错误码,直接查询官方手册指引',
                style: TextStyle(color: AppColors.secondary, fontSize: 15),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _brandController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.text, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: '品牌',
                  hintText: '如 Bosch',
                  prefixIcon: Icon(
                    Icons.factory_outlined,
                    color: AppColors.secondary,
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入品牌' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codeController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: AppColors.text, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: '错误码',
                  hintText: '如 E24',
                  prefixIcon: Icon(Icons.tag, color: AppColors.secondary),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入错误码' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search, size: 22),
                label: const Text('查询手册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
