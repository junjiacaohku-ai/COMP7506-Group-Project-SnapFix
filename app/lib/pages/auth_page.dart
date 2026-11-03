import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../api.dart';
import '../auth.dart';
import '../social_auth.dart';
import '../theme.dart';
import '../ui.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth});

  final AuthController auth;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _register = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.auth.register(
          _nameController.text,
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await widget.auth.login(
          _emailController.text,
          _passwordController.text,
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法完成操作，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _socialLogin(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code != AuthorizationErrorCode.canceled && mounted) {
        setState(() => _error = 'Apple 登录未完成，请稍后重试');
      }
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(() => _error = error.description ?? 'Google 登录未完成，请重试');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法完成第三方登录，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMode(bool register) {
    if (_busy || _register == register) return;
    setState(() {
      _register = register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 50),
                ),
                const SizedBox(height: 28),
                const Text(
                  '欢迎使用 SnapFix',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '登录后，你的诊断档案和维修进度\n会保存在个人账号下。',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _ModeButton(
                        label: '登录',
                        selected: !_register,
                        onTap: () => _setMode(false),
                      ),
                      _ModeButton(
                        label: '注册',
                        selected: _register,
                        onTap: () => _setMode(true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_register) ...[
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            style: const TextStyle(color: AppColors.text),
                            decoration: const InputDecoration(
                              labelText: '你的称呼',
                              hintText: '例如：峻嘉',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (value) {
                              final length = value?.trim().length ?? 0;
                              if (length == 0 || length > 30) {
                                return '昵称需为 1–30 个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          style: const TextStyle(color: AppColors.text),
                          decoration: const InputDecoration(
                            labelText: '邮箱',
                            hintText: 'name@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!email.contains('@') ||
                                !email.split('@').last.contains('.')) {
                              return '请输入有效的邮箱地址';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          style: const TextStyle(color: AppColors.text),
                          decoration: InputDecoration(
                            labelText: '密码',
                            hintText: _register ? '至少 8 个字符' : '输入账号密码',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                            ),
                          ),
                          validator: (value) {
                            if ((value?.length ?? 0) < 8) {
                              return '密码至少需要 8 个字符';
                            }
                            if ((value?.length ?? 0) > 128) {
                              return '密码不能超过 128 个字符';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.red,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.red,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                GradientButton(
                  label: _register ? '创建账号' : '登录并继续',
                  icon: _register
                      ? Icons.person_add_alt_1_outlined
                      : Icons.arrow_forward_rounded,
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '或使用以下方式登录',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                if (Platform.isIOS || Platform.isMacOS) ...[
                  SignInWithAppleButton(
                    onPressed: _busy
                        ? null
                        : () => _socialLogin(widget.auth.loginWithApple),
                    text: '使用 Apple 登录',
                    height: 52,
                    style: SignInWithAppleButtonStyle.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(height: 12),
                ],
                if (SocialAuthService.googleConfigured)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _socialLogin(widget.auth.loginWithGoogle),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    label: const Text('使用 Google 登录'),
                  ),
                const SizedBox(height: 20),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.muted,
                      size: 15,
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '密码经过加盐哈希处理，不会以明文保存',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 11,
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
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.secondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
