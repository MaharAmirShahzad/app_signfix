import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.onBack,
  });
  final ApiClient api;
  final VoidCallback onAuthenticated;
  final VoidCallback? onBack; // back to portal selection
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _loading   = false;
  bool _obscure   = true;
  String? _error;
  bool _showRegister = false;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final pass  = _password.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.'); return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.'); return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Please enter your password.'); return;
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
  Widget build(BuildContext context) {
    if (_showRegister) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _showRegister = false);
        },
        child: RegisterScreen(
          api: widget.api,
          onAuthenticated: widget.onAuthenticated,
          onLoginTap: () => setState(() => _showRegister = false),
        ),
      );
    }

    return PopScope(
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
                icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
                onPressed: widget.onBack,
              )
            : null,
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/logo.jpeg', width: 30, height: 30, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          RichText(text: const TextSpan(children: [
            TextSpan(text: 'Sign', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            TextSpan(text: 'Fix', style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900)),
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
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .3), blurRadius: 20)],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Customer Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.white)),
                  const SizedBox(height: 6),
                  const Text('Order sign boards, request service\nand track every update.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textLight, height: 1.4, fontSize: 13)),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: AppColors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email address',
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
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.gold,
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
                        border: Border.all(color: AppColors.danger.withValues(alpha: .4)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                  ],

                  const SizedBox(height: 20),
                  LoadingButton(loading: _loading, onPressed: _submit, child: const Text('Sign In')),
                  const SizedBox(height: 10),

                  TextButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.navyDark,
                        title: const Text('Password Recovery', style: TextStyle(color: AppColors.white)),
                        content: const Text(
                          'Please contact SignFix support to reset your password.',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                        ],
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),

                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: AppColors.textMuted)),
                    GestureDetector(
                      onTap: () => setState(() => _showRegister = true),
                      child: const Text('Register',
                          style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    ), // Scaffold closes here (child of PopScope)
    ); // PopScope closes here
  } // build
} // _LoginScreenState
