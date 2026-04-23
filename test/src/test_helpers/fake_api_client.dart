import 'package:dio/dio.dart';
import 'package:fcd_app/src/core/http/api_client.dart';

typedef FakeGetHandler =
    Future<Map<String, dynamic>> Function(
      String path, {
      Map<String, dynamic>? queryParameters,
      bool authenticated,
    });
typedef FakePostHandler =
    Future<Map<String, dynamic>> Function(
      String path, {
      dynamic data,
      Map<String, dynamic>? queryParameters,
      bool authenticated,
    });

class FakeApiClient extends ApiClient {
  FakeApiClient({this.onGet, this.onPost}) : super(dio: Dio());

  FakeGetHandler? onGet;
  FakePostHandler? onPost;

  final List<GetCall> getCalls = <GetCall>[];
  final List<PostCall> postCalls = <PostCall>[];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    getCalls.add(
      GetCall(
        path: path,
        queryParameters: queryParameters,
        authenticated: authenticated,
      ),
    );
    if (onGet != null) {
      return onGet!(
        path,
        queryParameters: queryParameters,
        authenticated: authenticated,
      );
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    postCalls.add(
      PostCall(
        path: path,
        data: data,
        queryParameters: queryParameters,
        authenticated: authenticated,
      ),
    );
    if (onPost != null) {
      return onPost!(
        path,
        data: data,
        queryParameters: queryParameters,
        authenticated: authenticated,
      );
    }
    return <String, dynamic>{};
  }
}

class GetCall {
  const GetCall({
    required this.path,
    required this.queryParameters,
    required this.authenticated,
  });

  final String path;
  final Map<String, dynamic>? queryParameters;
  final bool authenticated;
}

class PostCall {
  const PostCall({
    required this.path,
    required this.data,
    required this.queryParameters,
    required this.authenticated,
  });

  final String path;
  final dynamic data;
  final Map<String, dynamic>? queryParameters;
  final bool authenticated;
}
