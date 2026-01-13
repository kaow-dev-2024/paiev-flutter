import 'package:flutter/material.dart';
import '../../services/auth_api.dart';
import 'login_screen.dart';
import 'otp_verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController(text: '');
  final _mobileController = TextEditingController(text: '');

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _onSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await AuthApi.sendRegisterVerifyCode(
      email: _emailController.text.trim(),
      mobile: _mobileController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งรหัสยืนยันไปที่อีเมล/มือถือแล้ว')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen.register(
            email: _emailController.text.trim(),
            mobile: _mobileController.text.trim(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งรหัสไม่สำเร็จ กรุณาลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register (สมัครสมาชิก)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กรอกอีเมลและเบอร์มือถือเพื่อสมัครสมาชิก',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'example@email.com',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกอีเมล';
                    if (!v.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile',
                    hintText: 'เช่น 0801234567',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกเบอร์มือถือ';
                    if (v.length < 9) return 'เบอร์มือถือต้องอย่างน้อย 9 หลัก';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onSendCode,
                    child: _isLoading
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('ส่งรหัสยืนยัน'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // ถ้ามี LoginScreen แล้ว ให้ push ไปหน้า login
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    },
                    child: const Text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
