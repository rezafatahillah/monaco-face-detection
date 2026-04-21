import 'package:dio/dio.dart';
import 'dart:typed_data';

class ApiService {
  final Dio _dio = Dio();
  final String baseUrl = 'http://192.168.0.108:3000';
  
  final String _token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiMmM3MDQxMy1hY2YwLTRjNzYtYjYwYy1mZDg5NmUwOTVhNzMiLCJ1c2VybmFtZSI6InN1cGVyYWRtaW5AbmVzdC5jb20iLCJzY29wZSI6ImFjY2VzcyIsImlhdCI6MTc3Njc3NzYzNywiZXhwIjoxNzc2NzgxMjM3LCJhdWQiOiIiLCJpc3MiOiIifQ.xyIEo3VzKxgblH4mNPXPGIoYyR3CpO0x7yYLqqpqkGM";

  Future<bool> uploadFaceImage(Uint8List imageBytes) async {
    try {
      FormData formData = FormData.fromMap({
        'code': 'FIL001',
        'dir': 'assets',
        'file': MultipartFile.fromBytes(imageBytes, filename: 'face_capture.png'),
      });

      final response = await _dio.post(
        '$baseUrl/v1.0/storages/uploads',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Gagal upload ke NestJS: $e");
      return false;
    }
  }

  Future<void> sendFaceData(String faceData) async {
    try {
      final response = await _dio.post('$baseUrl/face', data: {
        'data': faceData,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      print("Berhasil kirim: ${response.statusCode}");
    } catch (e) {
      print("Gagal konek ke NestJS: $e");
    }
  }
}