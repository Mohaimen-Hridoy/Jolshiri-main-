import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/mock_data.dart';
import '../../models/app_models.dart';
import '../../services/api_config.dart';
import '../../theme/app_theme.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final List<ChatbotMessage> _messages = List.of(MockData.chatStarter);
  bool _typing = false;

  static const _suggestions = [
    'Available plots',
    'Book an electrician',
    'Latest notices',
    'Report an SOS',
  ];

  /// Calls the Jolshiri backend's /api/chatbot/query endpoint which
  /// proxies to the AI service with Jolshiri context injected.
  /// Sends the last few turns as [history] so the AI can follow up on
  /// previous questions without losing context.
  /// Falls back to a local keyword reply if the backend is unreachable.
  Future<String> _getReply(String userMessage) async {
    try {
      final contextSummary = _buildContextSummary();

      // Build conversation history from the last 10 messages (5 turns),
      // excluding the greeting and the message we're about to send.
      final historyMessages = _messages
          .skip(1) // skip the opening greeting
          .take(10)
          .map((m) => {
                'role': m.fromUser ? 'user' : 'assistant',
                'text': m.text,
              })
          .toList();

      final uri = Uri.parse('${ApiConfig.baseUrl}/chatbot/query');
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (AuthSession.token != null)
                'Authorization': 'Bearer ${AuthSession.token}',
            },
            body: jsonEncode({
              'message': userMessage,
              'context': contextSummary,
              'history': historyMessages,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['reply'] as String? ?? _localFallback(userMessage);
      }
      return _localFallback(userMessage);
    } catch (_) {
      return _localFallback(userMessage);
    }
  }

  String _buildContextSummary() {
    final notices = MockData.notices.take(3).map((n) => n.title).join(', ');
    final providers = MockData.serviceProviders.take(5).map((p) => '${p.name} (${p.serviceType})').join(', ');
    final rentals = MockData.rentals.take(3).map((r) => '${r.title} at ${r.location}').join(', ');
    return 'Latest notices: $notices. '
        'Available service providers: $providers. '
        'Current to-let listings: $rentals. '
        'Community: Jolshiri Abashon Smart City, Purbachal, Dhaka.';
  }

  String _localFallback(String query) {
    final q = query.toLowerCase();
    if (q.contains('plot')) {
      return 'There are currently a few plots marked Available in Sector 7 and 15. Open the Property tab to view details or request a quote from a developer.';
    }
    if (q.contains('electric') || q.contains('service') || q.contains('plumb')) {
      return 'You can find verified electricians, plumbers, carpenters, and other service providers under the Services tab — each has ratings and reviews, and you can book them directly.';
    }
    if (q.contains('notice') || q.contains('announcement')) {
      return 'Check the Authority Portal tab for the latest notices, maintenance schedules, and announcements from Jolshiri management.';
    }
    if (q.contains('sos') || q.contains('emergency') || q.contains('security')) {
      return 'For emergencies, open the Security tab and file an incident report. The Jolshiri security control room will be notified immediately.';
    }
    if (q.contains('rent') || q.contains('to-let') || q.contains('to let')) {
      return 'Browse current rental listings or post your own under Property > To-Let. You can also request a viewing directly from the listing.';
    }
    if (q.contains('payment') || q.contains('bill')) {
      return 'Your payment history and pending dues are in the Payments tab. You can pay directly from there.';
    }
    return 'I can help you find plots, book services, check notices, or reach security. Try asking about one of those, or use the module tabs in the app.';
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final userMsg = ChatbotMessage(text: text.trim(), fromUser: true, time: DateTime.now());
    setState(() {
      _messages.add(userMsg);
      _typing = true;
    });
    _controller.clear();
    _scrollToBottom();

    _getReply(text.trim()).then((reply) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatbotMessage(text: reply, fromUser: false, time: DateTime.now()));
        _typing = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.brass),
            SizedBox(width: 8),
            Text('Jolshiri Assistant'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _messages.length) return const _TypingBubble();
                return _Bubble(message: _messages[i]);
              },
            ),
          ),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map((s) => OutlinedButton(
                          onPressed: () => _send(s),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8)),
                          child: Text(s, style: const TextStyle(fontSize: 12.5)),
                        ))
                    .toList(),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                          hintText: 'Ask about Jolshiri services…'),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.parade),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () => _send(_controller.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatbotMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.parade : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.line),
        ),
        child: Text(
          message.text,
          style: TextStyle(
              color: isUser ? Colors.white : AppColors.ink, height: 1.35),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line)),
        child: const SizedBox(
          width: 40,
          height: 12,
          child: _DotsAnimation(),
        ),
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final offset = ((_ctrl.value * 3 - i) % 3).clamp(0.0, 1.0);
            final opacity = offset < 0.5 ? offset * 2 : (1 - offset) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.3 + opacity * 0.7,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.parade,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
