class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.content,
    this.timestamp,
  });

  final String sender;
  final String content;
  final DateTime? timestamp;

  bool get isUser => sender == 'user';
  bool get isBot => sender == 'bot' || sender == 'assistant';
}
