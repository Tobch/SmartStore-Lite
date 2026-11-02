import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries = 3;

  RetryInterceptor(this.dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && err.requestOptions.extra['retries'] != maxRetries) {
      int retries = err.requestOptions.extra['retries'] ?? 0;
      err.requestOptions.extra['retries'] = retries + 1;
      
      await Future.delayed(Duration(milliseconds: 1000 * (retries + 1))); // Exponential backoff
      
      try {
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        return super.onError(err, handler);
      }
    }
    super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout || 
           err.type == DioExceptionType.receiveTimeout ||
           (err.response?.statusCode != null && err.response!.statusCode! >= 500);
  }
}