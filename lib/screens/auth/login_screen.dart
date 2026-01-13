import 'package:flutter/material.dart';
import 'package:paievgo/screens/auth/register_screen.dart';
import '../../services/auth_api.dart';
import 'otp_verify_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(text: '');

  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await AuthApi.sendLoginOtp(
      identifier: _identifierController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่ง OTP ไปยังอีเมล์/มือถือเรียบร้อย')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen.login(
            identifier: _identifierController.text.trim(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่ง OTP ไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login (เข้าสู่ระบบ)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เข้าสู่ระบบด้วยอีเมลหรือเบอร์มือถือ',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _identifierController,
                  decoration: const InputDecoration(
                    labelText: 'Email หรือ เบอร์มือถือ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'กรุณากรอก Email หรือ เบอร์มือถือ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSendOtp,
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ส่ง OTP'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('ยังไม่มีบัญชี? สมัครสมาชิก'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
