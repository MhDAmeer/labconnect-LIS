import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../state/session_controller.dart';
import 'helix_background.dart';

/// Username and password login using the API guide's default tenant.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _usernameFocus = FocusNode();

  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = context.read<SessionController>().takeNotice();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final session = context.read<SessionController>();
    try {
      await session.login(
        username: _username.text,
        password: _password.text,
        tenantCode: AppConfig.defaultTenant,
      );
      // On success the app root swaps this screen for Home.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e);
        _password.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF020B24),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(child: HelixBackground()),
            SafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    media.viewInsets.bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: media.size.height -
                          media.padding.vertical -
                          media.viewInsets.bottom,
                    ),
                    child: Column(
                      children: [
                        // Leaves the upper part of the screen to the helix.
                        SizedBox(height: media.size.height * 0.30),
                        const _Heading(),
                        const SizedBox(height: 24),
                        _buildForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                controller: _username,
                focusNode: _usernameFocus,
                label: 'Username',
                icon: Icons.person_outline,
                action: TextInputAction.next,
                autofill: const [AutofillHints.username],
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                formatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter your username' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _password,
                focusNode: _passwordFocus,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: _hidePassword,
                action: TextInputAction.done,
                autofill: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Enter your password' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    FocusNode? focusNode,
    bool obscure = false,
    TextInputAction action = TextInputAction.next,
    Iterable<String>? autofill,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      enabled: !_busy,
      textInputAction: action,
      autofillHints: autofill,
      autocorrect: false,
      enableSuggestions: !obscure,
      inputFormatters: formatters,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        suffixIcon: suffix,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'LabConnect',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Sign in to view patients, orders and results',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFB8C7EA), fontSize: 15),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.abnormal.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.abnormal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.abnormal,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
