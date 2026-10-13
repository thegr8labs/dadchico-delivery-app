import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_style.dart';

/// Emails the delivery partner a password reset link. The link opens a web page where they
/// choose a new password, then they come back here to sign in.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  late final TextEditingController _email = TextEditingController(text: Get.arguments is String ? Get.arguments as String : '');
  bool _loading = false;
  bool _sent = false;
  String _error = '';

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter the email address you use to sign in.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _authService.forgotPassword(email);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0, foregroundColor: AppColors.textPrimary),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _sent ? _sentView() : _formView(),
        ),
      ),
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot password?', style: AppStyle.heading1.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        Text(
          "Enter your delivery partner email and we'll send you a link to set a new password.",
          style: AppStyle.subtitle,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          style: AppStyle.title,
          onChanged: (_) {
            if (_error.isNotEmpty) setState(() => _error = '');
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Email address',
            labelStyle: AppStyle.subtitle,
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.6),
            ),
          ),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_error, style: AppStyle.body.copyWith(color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : Text('Send reset link', style: AppStyle.title.copyWith(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _sentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.primaryTint, shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_outlined, size: 36, color: AppColors.primaryGreen),
          ),
        ),
        const SizedBox(height: 24),
        Text('Check your email', textAlign: TextAlign.center, style: AppStyle.heading1.copyWith(fontSize: 24)),
        const SizedBox(height: 10),
        Text(
          'If ${_email.text.trim()} is a delivery partner account, a reset link is on its way. '
          'Open it within 10 minutes, choose a new password, then come back and sign in.',
          textAlign: TextAlign.center,
          style: AppStyle.subtitle,
        ),
        const SizedBox(height: 8),
        Text("Can't find it? Check your spam folder.", textAlign: TextAlign.center, style: AppStyle.caption),
        const SizedBox(height: 28),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: Get.back,
            child: Text('Back to sign in', style: AppStyle.title.copyWith(color: Colors.white)),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : () => setState(() => _sent = false),
          child: const Text('Send again'),
        ),
      ],
    );
  }
}
