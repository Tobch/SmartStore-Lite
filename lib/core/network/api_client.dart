import 'package:dio/dio.dart';
import '../../app_config.dart';
import 'interceptors/header_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _dio.interceptors.addAll([
      HeaderInterceptor(),
      ErrorMappingInterceptor(),
      CustomLoggingInterceptor(),
      RetryInterceptor(_dio),
    ]);
  }

  Dio get client => _dio;
}