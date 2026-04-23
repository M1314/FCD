import 'package:fcd_app/src/core/errors/app_exception.dart';

String userMessageFromError(Object error, {required String fallbackMessage}) {
  if (error is AppException) {
    final message = error.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  return fallbackMessage;
}
