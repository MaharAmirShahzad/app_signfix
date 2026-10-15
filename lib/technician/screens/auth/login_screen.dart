import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../registration/reg_step1_personal.dart';
import '../registration/registration_data.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.onBack,
  });
  final TechnicianApi api;
  final VoidCallback onAuthenticated;
  final VoidCallback? onBack;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final pass  = _password.text;

    if (email.isEmpty) {
      setState(() => _error = 'Work email is required.'); return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.'); return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Password is required.'); return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.'); return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await widget.api.login(email, pass);
      widget.onAuthenticated();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.navyDeep,
        appBar: AppBar(
          backgroundColor: AppColors.navyDark,
          leading: widget.onBack != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: AppColors.gold),
                  onPressed: widget.onBack,
                )
              : null,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.jpeg',
                  width: 30, height: 30, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            RichText(
                text: const TextSpan(children: [
              TextSpan(
                  text: 'Sign',
                  style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              TextSpan(
                  text: 'Fix',
                  style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              TextSpan(
                  text: '  Tech',
                  style: TextStyle(
                      color: AppColors.info,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ])),
          ]),
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.info.withValues(alpha: .5),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.info.withValues(alpha: .25),
                                blurRadius: 20)
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/images/logo.jpeg',
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('Technician Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white)),
                    const SizedBox(height: 6),
                    const Text('Fast, guided field service by SignFix',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textLight, fontSize: 13)),
                    const SizedBox(height: 28),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.white),
                      decoration: const InputDecoration(
                        labelText: 'Work email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.info,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: .4)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    LoadingButton(
                        loading: _loading,
                        onPressed: _submit,
                        child: const Text('Start Work')),
                    const SizedBox(height: 16),

                    // Divider
                    const Row(children: [
                      Expanded(child: Divider(color: AppColors.navyLight)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: AppColors.navyLight)),
                    ]),
                    const SizedBox(height: 14),

                    // Create Account button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegStep1Personal(
                              api: widget.api,
                              data: TechRegistrationData(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('New Technician? Create Account'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.info,
                          side: BorderSide(
                              color: AppColors.info.withValues(alpha: .5)),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        'New accounts require admin approval before access.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ), // Scaffold
    ); // PopScope
}
