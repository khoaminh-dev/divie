import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;
      // DiVie uses the simplest signup flow: when email confirmation is
      // disabled in Supabase, signup returns an active session immediately.
      // Do not send the user into an email-confirmation flow here.
      if (response.session != null) {
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(
          () => _errorMessage =
              'Tài khoản chưa tạo phiên đăng nhập. Hãy tắt yêu cầu xác nhận email trong Supabase.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _friendlyAuthError(error));
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Không thể tạo tài khoản. Vui lòng kiểm tra kết nối và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    final statusCode = error.statusCode?.toString().toLowerCase() ?? '';
    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('user already exists')) {
      return 'Email này đã được đăng ký. Bạn hãy đăng nhập hoặc dùng email khác.';
    }
    if (message.contains('password should be at least') ||
        message.contains('password')) {
      return 'Mật khẩu chưa đủ mạnh. Hãy dùng ít nhất 6 ký tự.';
    }
    if (statusCode == '429' ||
        message.contains('rate limit') ||
        message.contains('too many') ||
        message.contains('over_email_send_rate_limit')) {
      return 'Supabase đang giới hạn gửi email. DiVie không dùng xác nhận email; hãy tắt yêu cầu xác nhận email trong Supabase để đăng ký ngay.';
    }
    if (message.contains('invalid email') ||
        message.contains('email_address_invalid') ||
        message.contains('email address is invalid')) {
      return 'Email chưa đúng định dạng. Hãy nhập dạng ten@mien.com.';
    }
    return 'Đăng ký chưa thành công: ${error.message}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SignUpBrandHeader(),
                    const SizedBox(height: 30),
                    Text(
                      'Tạo tài khoản',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: DivieColors.navy,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng ký để bắt đầu sử dụng DiVie.',
                      style: TextStyle(color: DivieColors.muted, fontSize: 16),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: _inputDecoration(
                        'Email',
                        Icons.mail_outline_rounded,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Nhập email của bạn.';
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Email chưa đúng định dạng.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: _inputDecoration(
                        'Mật khẩu',
                        Icons.lock_outline_rounded,
                        suffix: IconButton(
                          tooltip: _obscurePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? 'Mật khẩu cần ít nhất 6 ký tự.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _signUp(),
                      decoration: _inputDecoration(
                        'Nhập lại mật khẩu',
                        Icons.lock_reset_outlined,
                        suffix: IconButton(
                          tooltip: _obscureConfirmPassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Mật khẩu nhập lại chưa khớp.'
                          : null,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: DivieColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: FilledButton.styleFrom(
                        backgroundColor: DivieColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Đăng ký',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đã có tài khoản? Đăng nhập'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tài khoản được bảo vệ bởi Supabase Auth.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DivieColors.muted, fontSize: 13),
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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0x180E7680)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: DivieColors.teal, width: 2),
      ),
    );
  }
}

class _SignUpBrandHeader extends StatelessWidget {
  const _SignUpBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2212A9B5),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/branding/divie_logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'DiVie',
          style: TextStyle(
            color: DivieColors.navy,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
