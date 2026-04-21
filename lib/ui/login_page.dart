import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import '../core/services/token_service.dart';
import 'face_detection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    try {
      final url = '${dotenv.env['BASE_URL']}${dotenv.env['API_VERSION']}/auth/login';
      final response = await Dio().post(url, data: {
        "username": dotenv.env['APP_USER'],
        "password": dotenv.env['APP_PASS'],
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        await TokenService.saveTokens(response.data['data']['accessToken'], response.data['data']['refreshToken']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FaceDetectionPage()));
      }
    } catch (e) {
      debugPrint("Gagal Auto Login: $e");
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}