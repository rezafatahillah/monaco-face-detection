import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../core/network/dio_client.dart';

class ApiService {
  Future<bool> uploadFaceImage(Uint8List imageBytes) async {
    try {
      FormData formData = FormData.fromMap({
        'code': 'FIL001', 'dir': 'assets',
        'file': MultipartFile.fromBytes(imageBytes, filename: 'face.png'),
      });
      final response = await DioClient.instance.post('/v1.0/storages/uploads', data: formData);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendFaceData(String faceData) async {
    try {
      await DioClient.instance.post('/face', data: {
        'data': faceData,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Gagal kirim data: $e");
    }
  }
}