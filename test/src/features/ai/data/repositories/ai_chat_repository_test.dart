import 'package:fcd_app/src/core/errors/app_exception.dart';
import 'package:fcd_app/src/features/ai/data/repositories/ai_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../test_helpers/fake_api_client.dart';

void main() {
  group('AiChatRepository', () {
    test(
      'saveChatMessage sends expected payload and succeeds on 200',
      () async {
        final apiClient = FakeApiClient(
          onPost: (_, {data, queryParameters, authenticated = false}) async =>
              <String, dynamic>{'intResponse': 200},
        );
        final repository = AiChatRepository(apiClient: apiClient);

        await repository.saveChatMessage(
          chatId: 6,
          userId: 2,
          sender: 'user',
          message: 'hola',
        );

        expect(apiClient.postCalls, hasLength(1));
        final call = apiClient.postCalls.single;
        expect(call.path, '/chats/6/messages');
        expect(call.authenticated, isTrue);
        expect(call.data, <String, dynamic>{
          'user_id': 2,
          'sender': 'user',
          'message': 'hola',
        });
      },
    );

    test('saveChatMessage throws AppException on non-200 response', () async {
      final apiClient = FakeApiClient(
        onPost: (_, {data, queryParameters, authenticated = false}) async =>
            <String, dynamic>{'intResponse': 403, 'strAnswer': 'Sin permiso'},
      );
      final repository = AiChatRepository(apiClient: apiClient);

      expect(
        () => repository.saveChatMessage(
          chatId: 6,
          userId: 2,
          sender: 'user',
          message: 'hola',
        ),
        throwsA(
          isA<AppException>()
              .having((error) => error.message, 'message', 'Sin permiso')
              .having((error) => error.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('getPrompts keeps only valid category/prompt pairs', () async {
      final apiClient = FakeApiClient(
        onGet: (_, {queryParameters, authenticated = false}) async =>
            <String, dynamic>{
              'intResponse': 200,
              'Result': <String, dynamic>{
                'prompts': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'category': 'Cursos',
                    'prompt_text': 'Ayuda con cursos',
                  },
                  <String, dynamic>{'category': '', 'prompt_text': 'invalido'},
                  <String, dynamic>{'category': 'Oraculo', 'prompt_text': ''},
                ],
              },
            },
      );
      final repository = AiChatRepository(apiClient: apiClient);

      final prompts = await repository.getPrompts();

      expect(prompts, <String, String>{'Cursos': 'Ayuda con cursos'});
    });

    test('hasAiAccess returns true when subscription check succeeds', () async {
      final apiClient = FakeApiClient(
        onGet: (path, {queryParameters, authenticated = false}) async =>
            <String, dynamic>{'intResponse': 200},
        onPost: (path, {data, queryParameters, authenticated = false}) async =>
            <String, dynamic>{'intResponse': 0},
      );
      final repository = AiChatRepository(apiClient: apiClient);

      final hasAccess = await repository.hasAiAccess(9);

      expect(hasAccess, isTrue);
      expect(apiClient.getCalls, hasLength(1));
      expect(apiClient.postCalls, isEmpty);
    });

    test(
      'hasAiAccess falls back to trial check when subscription fails',
      () async {
        final apiClient = FakeApiClient(
          onGet: (path, {queryParameters, authenticated = false}) async =>
              <String, dynamic>{'intResponse': 401},
          onPost:
              (path, {data, queryParameters, authenticated = false}) async =>
                  <String, dynamic>{'intResponse': 200},
        );
        final repository = AiChatRepository(apiClient: apiClient);

        final hasAccess = await repository.hasAiAccess(9);

        expect(hasAccess, isTrue);
        expect(apiClient.getCalls, hasLength(1));
        expect(apiClient.postCalls, hasLength(1));
        expect(apiClient.postCalls.single.path, '/ai-trial/check');
      },
    );
  });
}
