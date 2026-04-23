import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/core/http/api_client.dart';
import 'package:fcd_app/src/core/utils/json_utils.dart';
import 'package:fcd_app/src/features/ai/data/models/chat_message.dart';

class AiChatRepository {
  AiChatRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<Map<String, String>> getPrompts() async {
    final payload = await _apiClient.get('/prompts', authenticated: true);
    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      return <String, String>{};
    }

    final prompts = asList(asMap(payload['Result'])['prompts']);
    final result = <String, String>{};

    for (final item in prompts) {
      final raw = asMap(item);
      final category = readString(raw, const <String>['category']);
      final prompt = readString(raw, const <String>['prompt_text']);
      if (category.isNotEmpty && prompt.isNotEmpty) {
        result[category] = prompt;
      }
    }

    return result;
  }

  Future<List<ChatMessage>> getChatMessages({
    required int userId,
    required String chatTitle,
  }) async {
    final payload = await _apiClient.get('/chats/$userId', authenticated: true);
    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      return <ChatMessage>[];
    }

    final chats = asList(asMap(payload['Result'])['chats']);
    final current = chats
        .map(asMap)
        .firstWhere(
          (chat) => readString(chat, const <String>['title']) == chatTitle,
          orElse: () => <String, dynamic>{},
        );

    if (current.isEmpty) {
      return <ChatMessage>[];
    }

    final messages = asList(current['messages']);
    return messages
        .map(asMap)
        .map(
          (message) => ChatMessage(
            sender: readString(message, const <String>['sender']),
            content: readString(message, const <String>['message', 'content']),
          ),
        )
        .where((message) => message.content.isNotEmpty)
        .toList();
  }

  Future<void> saveChatMessage({
    required int chatId,
    required int userId,
    required String sender,
    required String message,
  }) async {
    final payload = await _apiClient.post(
      '/chats/$chatId/messages',
      authenticated: true,
      data: <String, dynamic>{
        'user_id': userId,
        'sender': sender,
        'message': message,
      },
    );

    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ??
            'No se pudo guardar el mensaje del chat.',
        statusCode: status,
      );
    }
  }

  Future<String> askAi({
    required int userId,
    required int chatId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final payload = await _apiClient.post(
      '/chatAI/chatBot',
      authenticated: true,
      data: <String, dynamic>{
        'arrMessages': messages,
        'user_id': userId,
        'chat_id': chatId,
      },
    );

    final status = payload['intResponse'] as int? ?? 500;
    if (status != 200) {
      throw AppException(
        payload['strAnswer']?.toString() ??
            'No se pudo obtener respuesta de la IA.',
        statusCode: status,
      );
    }

    final answer = payload['strAnswer']?.toString() ?? '';
    if (answer.trim().isEmpty) {
      throw const AppException('La IA no devolvio respuesta.');
    }

    return answer;
  }

  Future<bool> hasAiAccess(int userId) async {
    final subs = await _apiClient.get(
      '/ai-plan/user-check',
      queryParameters: <String, dynamic>{'user_id': userId.toString()},
      authenticated: true,
    );

    final subsStatus = subs['intResponse'] as int? ?? 0;
    if (subsStatus == 200) {
      return true;
    }

    final trial = await _apiClient.post(
      '/ai-trial/check',
      authenticated: true,
      data: <String, dynamic>{'user_id': userId},
    );

    return (trial['intResponse'] as int? ?? 0) == 200;
  }
}
