import 'package:dio/dio.dart';
import '../../../app_config.dart';

class HeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['User-Agent'] = AppConfig.appUserAgent;
    options.headers['Accept'] = 'application/json';
    super.onRequest(options, handler);
  }
}