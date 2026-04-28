import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/config/api_config.dart';
import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/core/storage/app_storage.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    this.onUnauthorized,
    this.onTokenRefreshed,
    required this.storage,
  }) : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              responseType: ResponseType.json,
              headers: <String, dynamic>{'Content-Type': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final isRefreshCall =
              error.requestOptions.path.endsWith('/refresh') ||
              error.requestOptions.path.contains('/refresh?');
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          if (_isUnauthorized(error) &&
              _refreshToken != null &&
              !isRefreshCall &&
              !alreadyRetried) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final retry = await _retry(error.requestOptions);
              return handler.resolve(retry);
            }
          }

          return handler.reject(error);
        },
      ),
    );
  }

  final Dio _dio;
  final AsyncVoidCallback? onUnauthorized;
  final AsyncValueChanged<String>? onTokenRefreshed;
  final AppStorage storage;

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshingFuture;

  Dio get dio => _dio;

  void setTokens({
    required String? accessToken,
    required String? refreshToken,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        options: _buildOptions(authenticated: authenticated),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _buildOptions(authenticated: authenticated),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> postWithHeaders(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    bool authenticated = false,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        path,
        data: data,
        options: _buildOptions(authenticated: authenticated),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    dynamic data,
    bool authenticated = false,
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        path,
        data: data,
        options: _buildOptions(authenticated: authenticated),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<Response<dynamic>> download(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  bool _isUnauthorized(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 401 || statusCode == 403;
  }

  Options _buildOptions({required bool authenticated}) {
    if (!authenticated || _accessToken == null || _accessToken!.isEmpty) {
      return Options();
    }

    return Options(
      headers: <String, dynamic>{'Authorization': 'Bearer $_accessToken'},
    );
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      await onUnauthorized?.call();
      return false;
    }

    if (_refreshingFuture != null) {
      return _refreshingFuture!;
    }

    _refreshingFuture = _refreshTokenRequest();
    final refreshed = await _refreshingFuture!;
    _refreshingFuture = null;
    return refreshed;
  }

  Future<bool> _refreshTokenRequest() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/refresh',
        data: '',
        options: Options(
          headers: <String, dynamic>{'Authorization': 'Bearer $_refreshToken'},
        ),
      );

      final payload = response.data ?? <String, dynamic>{};
      final newAccess = payload['access_token']?.toString() ?? '';
      if (newAccess.isEmpty) {
        await onUnauthorized?.call();
        return false;
      }

      _accessToken = newAccess;
      await onTokenRefreshed?.call(newAccess);
      return true;
    } on DioException {
      await onUnauthorized?.call();
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    final options = Options(
      method: requestOptions.method,
      headers: <String, dynamic>{
        ...requestOptions.headers,
        'Authorization': 'Bearer $_accessToken',
      },
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      extra: requestOptions.extra,
      followRedirects: requestOptions.followRedirects,
      listFormat: requestOptions.listFormat,
      maxRedirects: requestOptions.maxRedirects,
      persistentConnection: requestOptions.persistentConnection,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      requestEncoder: requestOptions.requestEncoder,
      responseDecoder: requestOptions.responseDecoder,
      validateStatus: requestOptions.validateStatus,
    );

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options.copyWith(
        extra: <String, dynamic>{...requestOptions.extra, 'retried': true},
      ),
    );
  }

  AppException _mapDioException(DioException error) {
    final data = error.response?.data;
    int? statusCode;
    String message = 'Algo salio mal. Intentalo de nuevo.';

    if (data is Map<String, dynamic>) {
      statusCode = data['intResponse'] as int? ?? error.response?.statusCode;
      message =
          data['strAnswer']?.toString() ??
          data['message']?.toString() ??
          message;
    } else {
      statusCode = error.response?.statusCode;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'La conexión tardó demasiado. Revisa tu internet.';
    }

    if (error.type == DioExceptionType.connectionError) {
      message = 'No se pudo conectar con el servidor.';
    }

    return AppException(message, statusCode: statusCode);
  }

  AppException mapException(DioException error) => _mapDioException(error);
}

typedef AsyncVoidCallback = FutureOr<void> Function();
typedef AsyncValueChanged<T> = FutureOr<void> Function(T value);
