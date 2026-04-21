import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/token_service.dart';

class DioClient {
  static final String _baseUrl = dotenv.env['BASE_URL'] ?? 'http://192.168.0.108:3000';
  static final String _version = dotenv.env['API_VERSION'] ?? '/v1.0';
  static final Dio _dio = Dio(BaseOptions(baseUrl: _baseUrl));

  static Dio get instance {
    _dio.interceptors.clear();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenService.getAccessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          final refresh = await TokenService.getRefreshToken();
          try {
            final res = await Dio().post('$_baseUrl$_version/auth/refresh',
                options: Options(headers: {'Authorization': 'Bearer $refresh'}));
            await TokenService.saveTokens(res.data['accessToken'], res.data['refreshToken']);
            return handler.resolve(await _retry(e.requestOptions));
          } catch (_) {
            await TokenService.clear();
          }
        }
        return handler.next(e);
      },
    ));
    return _dio;
  }

  static Future<Response> _retry(RequestOptions ro) async {
    final token = await TokenService.getAccessToken();
    return _dio.request(ro.path, options: Options(method: ro.method, headers: {'Authorization': 'Bearer $token'}), data: ro.data);
  }
}