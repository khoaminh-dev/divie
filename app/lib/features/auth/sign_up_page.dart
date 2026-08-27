import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/account_profile_service.dart';
import '../../core/data/device_registration_service.dart';
import '../../core/roles/app_role.dart';
import '../../main.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  AppRole _role = AppRole.elder;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final name = _nameController.text.trim();
    final phone = _normalizePhone(_phoneController.text);

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {
          'full_name': name,
          'name': name,
          'divie_role': _role.storageValue,
          'phone_number': phone,
        },
      );

      if (!mounted) return;
      // DiVie uses the simplest signup flow: when email confirmation is
      // disabled in Supabase, signup returns an active session immediately.
      // Do not send the user into an email-confirmation flow here.
      if (response.session != null) {
        await AccountProfileService(
          Supabase.instance.client,
        ).ensureCurrentProfile(preferredName: name);
        await AppRoleStore().save(_role);
        await DeviceRegistrationService(
          client: Supabase.instance.client,
        ).syncRole(_role);
        if (!mounted) return;
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(
          () => _errorMessage =
              'Hệ thống chưa thể đăng nhập ngay sau khi đăng ký. Vui lòng thử lại sau ít phút.',
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
      return 'Hệ thống đang nhận quá nhiều yêu cầu đăng ký. Bạn thử lại sau ít phút nhé.';
    }
    if (message.contains('invalid email') ||
        message.contains('email_address_invalid') ||
        message.contains('email address is invalid')) {
      return 'Email chưa đúng định dạng. Hãy nhập dạng ten@mien.com.';
    }
    return 'Đăng ký chưa thành công. Bạn kiểm tra lại kết nối rồi thử lại nhé.';
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
                    const SizedBox(height: 22),
                    const Text(
                      'Bạn đang dùng DiVie với vai trò nào?',
                      style: TextStyle(
                        color: DivieColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppRole>(
                      segments: const [
                        ButtonSegment(
                          value: AppRole.elder,
                          icon: Icon(Icons.elderly_rounded),
                          label: Text('Người cao tuổi'),
                        ),
                        ButtonSegment(
                          value: AppRole.family,
                          icon: Icon(Icons.family_restroom_rounded),
                          label: Text('Người thân'),
                        ),
                      ],
                      selected: {_role},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.comfortable,
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : DivieColors.deepTeal,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? DivieColors.teal
                              : Colors.white,
                        ),
                      ),
                      onSelectionChanged: (selected) =>
                          setState(() => _role = selected.first),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: _inputDecoration(
                        'Tên tài khoản',
                        Icons.person_outline_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nhập tên tài khoản.';
                        }
                        if (value.trim().length > 60) {
                          return 'Tên tài khoản tối đa 60 ký tự.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: _inputDecoration(
                        'Số điện thoại',
                        Icons.phone_rounded,
                      ),
                      validator: (value) {
                        final phone = _normalizePhone(value ?? '');
                        if (phone.isEmpty) return 'Nhập số điện thoại của bạn.';
                        if (!RegExp(r'^0(?:3|5|7|8|9)\d{8}$').hasMatch(phone)) {
                          return 'Nhập số điện thoại Việt Nam hợp lệ.';
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

  static String _normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+84')) return '0${digits.substring(3)}';
    if (digits.startsWith('84') && digits.length == 11) {
      return '0${digits.substring(2)}';
    }
    return digits;
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
