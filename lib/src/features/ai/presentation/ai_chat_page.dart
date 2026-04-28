import 'package:fcd_app/src/core/errors/error_ui.dart';
import 'package:fcd_app/src/core/theme/app_theme.dart';
import 'package:fcd_app/src/features/ai/data/models/chat_message.dart';
import 'package:fcd_app/src/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  static const List<String> _chatTabs = <String>[
    'Sabiduria',
    'Meditacion',
    'Oraculo',
    'Guia Personal (ESH)',
    'Cursos',
  ];

  static const Map<String, int> _chatIds = <String, int>{
    'Sabiduria': 1,
    'Meditacion': 2,
    'Oraculo': 3,
    'Guia Personal (ESH)': 4,
    'Cursos': 5,
  };

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _checkingAccess = true;
  bool _hasAccess = false;
  bool _accessCheckFailed = false;
  bool _sending = false;
  String _activeChat = _chatTabs.first;
  String? _error;
  String? _accessError;

  List<ChatMessage> _messages = <ChatMessage>[];
  Map<String, String> _prompts = <String, String>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_accessCheckFailed) {
      return _AccessErrorView(
        message:
            _accessError ??
            'No pudimos validar tu acceso a IA en este momento.',
        onRetry: _bootstrap,
      );
    }

    if (!_hasAccess) {
      return _NoAccessView(onRetry: _bootstrap);
    }

    return Column(
      children: <Widget>[
        _buildTabSelector(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildMessages(),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
            ),
          ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 54,
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final tab = _chatTabs[index];
          final selected = tab == _activeChat;
          return ChoiceChip(
            selected: selected,
            label: Text(tab),
            onSelected: (_) => _changeChat(tab),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: _chatTabs.length,
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Inicia una conversacion con ESH para resolver dudas sobre tus cursos.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final fromUser = message.isUser;

        return Align(
          alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fromUser ? AppTheme.deepBrown : const Color(0xFFF3E7D6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: fromUser ? Colors.white : AppTheme.deepBrown,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Pregunta a ESH...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : _sendMessage,
              style: FilledButton.styleFrom(
                minimumSize: const Size(56, 52),
                padding: EdgeInsets.zero,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bootstrap() async {
    final session = context.read<SessionController>();
    final user = session.user;

    if (user == null) {
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
        _accessCheckFailed = true;
        _accessError = 'Sesión no válida. Vuelve a iniciar sesión.';
      });
      return;
    }

    setState(() {
      _checkingAccess = true;
      _accessCheckFailed = false;
      _accessError = null;
      _error = null;
    });

    try {
      final hasAccess = await session.aiChatRepository.hasAiAccess(user.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _hasAccess = hasAccess;
        _checkingAccess = false;
        _accessCheckFailed = false;
      });

      if (!hasAccess) {
        return;
      }

      _prompts = await session.aiChatRepository.getPrompts();
      await _loadMessagesForChat(_activeChat);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingAccess = false;
        _hasAccess = false;
        _accessCheckFailed = true;
        _accessError = userMessageFromError(
          error,
          fallbackMessage:
              'No pudimos validar tu acceso a IA. Verifica tu conexion e intenta de nuevo.',
        );
      });
    }
  }

  Future<void> _changeChat(String chat) async {
    if (chat == _activeChat || _loading) {
      return;
    }

    setState(() {
      _activeChat = chat;
      _error = null;
    });

    await _loadMessagesForChat(chat);
  }

  Future<void> _loadMessagesForChat(String chat) async {
    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = await session.aiChatRepository.getChatMessages(
        userId: user.id,
        chatTitle: chat,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = <ChatMessage>[
          const ChatMessage(
            sender: 'system',
            content:
                'Soy ESH. Te acompano en tu estudio. Puedes preguntarme sobre contenido del curso.',
          ),
          ...history,
        ];
        _loading = false;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = userMessageFromError(
          error,
          fallbackMessage: 'No se pudo cargar el historial del chat.',
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final raw = _inputController.text.trim();
    if (raw.isEmpty || _sending) {
      return;
    }

    final session = context.read<SessionController>();
    final user = session.user;
    if (user == null) {
      return;
    }

    final chatId = _chatIds[_activeChat] ?? 1;
    _inputController.clear();

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(ChatMessage(sender: 'user', content: raw));
      _messages.add(
        const ChatMessage(sender: 'system', content: 'Pensando...'),
      );
    });
    _scrollToBottom();

    try {
      await session.aiChatRepository.saveChatMessage(
        chatId: chatId,
        userId: user.id,
        sender: 'user',
        message: raw,
      );

      final history = _messages
          .where((msg) => msg.isUser || msg.isBot)
          .map(
            (msg) => <String, dynamic>{
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.content,
            },
          )
          .toList();

      final prompt = _prompts[_activeChat] ?? '';
      final requestMessages = <Map<String, dynamic>>[
        if (prompt.isNotEmpty)
          <String, dynamic>{'role': 'system', 'content': prompt},
        ...history,
      ];

      final answer = await session.aiChatRepository.askAi(
        userId: user.id,
        chatId: chatId,
        messages: requestMessages,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(sender: 'bot', content: answer));
      });

      await session.aiChatRepository.saveChatMessage(
        chatId: chatId,
        userId: user.id,
        sender: 'bot',
        message: answer,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_messages.isNotEmpty && _messages.last.sender == 'system') {
          _messages.removeLast();
        }
        _messages.add(
          const ChatMessage(
            sender: 'system',
            content: 'No pude procesar tu solicitud en este momento.',
          ),
        );
        _error = userMessageFromError(
          error,
          fallbackMessage: 'No se pudo completar tu mensaje en este momento.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }
}

class _AccessErrorView extends StatelessWidget {
  const _AccessErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.wifi_off_rounded,
              size: 54,
              color: AppTheme.deepBrown,
            ),
            const SizedBox(height: 12),
            Text(
              'No pudimos validar tu acceso',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _NoAccessView extends StatelessWidget {
  const _NoAccessView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.lock_outline_rounded,
              size: 54,
              color: AppTheme.deepBrown,
            ),
            const SizedBox(height: 12),
            Text(
              'No tienes acceso activo a la IA',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Activa tu plan o prueba desde circulo-dorado.org para usar el asistente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Revisar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}
