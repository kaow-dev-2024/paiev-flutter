import 'dart:convert';
import 'package:flutter/material.dart';
import "package:http/http.dart" as http;

class AuthApi {
  // TODO: เปลี่ยนเป็น base api จริงของคุณ
  static const String baseApi = 'http://210.246.202.47:9000';

  // register
  static Future<bool> sendRegisterVerifyCode({
    required String email,
    required String mobile,
  }) async {
    final uri = Uri.parse('$baseApi/api/paiev/send_verify_code');

    final body = {"email": email, "mobile": mobile};

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    // คุณสามารถปรับ logic ตรงนี้ตาม response จริง
    return response.statusCode == 200;
  }

  static Future<bool> checkRegisterVerifyCode({
    required String email,
    required String mobile,
    required String code,
  }) async {
    final uri = Uri.parse('$baseApi/api/paiev/check_verify_code');

    final body = {"email": email, "mobile": mobile, "code": code};

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }

  // login
  static Future<bool> sendLoginOtp({required String identifier}) async {
    final uri = Uri.parse('$baseApi/api/auth/send-otp');

    final body = {"identifier": identifier};

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }

  static Future<bool> verifyLoginOtp({
    required String identifier,
    required String code,
  }) async {
    final uri = Uri.parse('$baseApi/api/auth/verify-otp');

    final body = {"identifier": identifier, "code": code};

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    // debugging output
    debugPrint('[API][POST] $uri');
    debugPrint('[API][POST] body=${jsonEncode(body)}');
    debugPrint('[API][POST] status=${response.statusCode}');
    debugPrint('[API][POST] response=${response.body}');

    // ปกติ endpoint นี้มักจะ return token, profile ฯลฯ
    // สามารถ parse เพิ่มทีหลังได้
    return response.statusCode == 200;
  }
}
