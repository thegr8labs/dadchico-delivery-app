import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/auth_controller.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';
import '../widgets/brand_lockup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _auth = Get.find<AuthController>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();
    _auth.login(_email.text, _password.text);
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: AppStyle.subtitle,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(AppColors.primaryGreen, 1.6),
      border: border(const Color(0xFFE2E8F0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    const Center(child: BrandLockup(logoHeight: 46)).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 44),
                    Text('Welcome back', style: AppStyle.heading1.copyWith(fontSize: 26)),
                    const SizedBox(height: 6),
                    Text('Sign in with your delivery partner account to start taking orders.', style: AppStyle.subtitle),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email, AutofillHints.username],
                      autocorrect: false,
                      style: AppStyle.title,
                      onChanged: (_) => _auth.errorMessage.value = '',
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      decoration: _decoration('Email address', Icons.mail_outline_rounded),
                    ),
                    const SizedBox(height: 14),
                    Obx(
                      () => TextField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        obscureText: _auth.isPasswordHidden.value,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        style: AppStyle.title,
                        onChanged: (_) => _auth.errorMessage.value = '',
                        onSubmitted: (_) => _submit(),
                        decoration: _decoration(
                          'Password',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            tooltip: _auth.isPasswordHidden.value ? 'Show password' : 'Hide password',
                            icon: Icon(
                              _auth.isPasswordHidden.value ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: _auth.togglePasswordVisibility,
                          ),
                        ),
                      ),
                    ),
                    Obx(() {
                      final message = _auth.errorMessage.value;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: message.isEmpty
                            ? const SizedBox(height: 24)
                            : Container(
                                key: ValueKey(message),
                                margin: const EdgeInsets.only(top: 14, bottom: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(message, style: AppStyle.body.copyWith(color: AppColors.error)),
                                    ),
                                  ],
                                ),
                              ),
                      );
                    }),
                    const SizedBox(height: 10),
                    Obx(
                      () => SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _auth.isLoading.value ? null : _submit,
                          child: _auth.isLoading.value
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Signing in…'),
                                  ],
                                )
                              : Text('Log in', style: AppStyle.title.copyWith(color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.support_agent_rounded, color: AppColors.primaryGreen),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Forgot your password or new here? Contact the Dadchico team.',
                              style: AppStyle.caption.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => launchUrl(Uri(scheme: 'tel', path: '+916238640827')),
                            child: const Text('Call'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        'By logging in, you agree to our Terms & Privacy Policy.',
                        style: AppStyle.caption,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
