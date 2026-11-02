import 'package:dio/dio.dart';

class ProductNotFoundException implements Exception {
  final String message;
  ProductNotFoundException(this.message);
  @override
  String toString() => message;
}

class ErrorMappingInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.data != null && response.data['status'] == 0) {
      // This Open Food Facts returns status: 0 if the barcode isn't in their database
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        error: ProductNotFoundException('Product not found in Open Food Facts. You can enter details manually.'),
      ));
      return;
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 404) {
      err = err.copyWith(error: ProductNotFoundException('Product barcode not found.'));
    }
    super.onError(err, handler);
  }
}