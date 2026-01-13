import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_api.dart';
import '../home/home_screen.dart';

enum OtpFlowType { register, login }

class OtpVerifyScreen extends StatefulWidget {
  final OtpFlowType flowType;

  // สำหรับ Register
  final String? email;
  final String? mobile;

  // สำหรับ Login
  final String? identifier;

  const OtpVerifyScreen._({
    // ignore: unused_element_parameter
    super.key,
    required this.flowType,
    this.email,
    this.mobile,
    this.identifier,
  });

  factory OtpVerifyScreen.register({
    required String email,
    required String mobile,
  }) {
    return OtpVerifyScreen._(
      flowType: OtpFlowType.register,
      email: email,
      mobile: mobile,
    );
  }

  factory OtpVerifyScreen.login({required String identifier}) {
    return OtpVerifyScreen._(
      flowType: OtpFlowType.login,
      identifier: identifier,
    );
  }

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _title {
    switch (widget.flowType) {
      case OtpFlowType.register:
        return 'ยืนยันการสมัครสมาชิก';
      case OtpFlowType.login:
        return 'ยืนยันการเข้าสู่ระบบ';
    }
  }

  String get _code {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _onConfirm() async {
    if (_code.length != 6 || _code.contains(RegExp(r'[^0-9]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรหัส 6 หลักให้ครบ')),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = false;

    if (widget.flowType == OtpFlowType.register) {
      success = await AuthApi.checkRegisterVerifyCode(
        email: widget.email!,
        mobile: widget.mobile!,
        code: _code,
      );
    } else {
      success = await AuthApi.verifyLoginOtp(
        identifier: widget.identifier!,
        code: _code,
      );
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ยืนยันรหัสสำเร็จ')));

      // หลังยืนยันสำเร็จ: ไปหน้า Home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ChargeApp()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสไม่ถูกต้อง หรือหมดอายุ')),
      );
    }
  }

  Future<void> _onResend() async {
    bool success = false;

    if (widget.flowType == OtpFlowType.register) {
      success = await AuthApi.sendRegisterVerifyCode(
        email: widget.email!,
        mobile: widget.mobile!,
      );
    } else {
      success = await AuthApi.sendLoginOtp(identifier: widget.identifier!);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งรหัสใหม่เรียบร้อย')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ส่งรหัสใหม่ไม่สำเร็จ')));
    }
  }

  void _onChangedBox(String value, int index) {
    if (value.isNotEmpty) {
      // ถ้าไม่ใช่อันสุดท้าย → ไปช่องถัดไป
      if (index < _focusNodes.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      // ถ้าลบแล้ว → ย้อนกลับช่องก่อนหน้า
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String subTitle;
    if (widget.flowType == OtpFlowType.register) {
      subTitle =
          'เราได้ส่งรหัสไปยัง ${widget.email ?? ''} / ${widget.mobile ?? ''}';
    } else {
      subTitle = 'เราได้ส่งรหัสไปยัง ${widget.identifier ?? ''}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subTitle, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),

                // 🔢 OTP 6 ช่อง
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLength: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(1),
                          ],
                          decoration: const InputDecoration(counterText: ''),
                          onChanged: (v) => _onChangedBox(v, index),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onConfirm,
                    child: _isLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ยืนยันรหัส'),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _onResend,
                    child: const Text('ส่งรหัสอีกครั้ง'),
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
