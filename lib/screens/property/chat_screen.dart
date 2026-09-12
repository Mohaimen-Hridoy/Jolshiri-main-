import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../services/api_client.dart';
import '../../services/api_config.dart';
import '../../services/backend_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// In-app chat for one flat viewing request — talks to
/// GET/POST /api/viewing-requests/:id/messages. Used from the "Flat View
/// Requests" screen when the requester (or the listing owner) taps the
/// messaging icon on a request card.
class ChatScreen extends StatefulWidget {
  final String viewingRequestId;
  final String otherPartyName;
  final String listingTitle;

  const ChatScreen({
    super.key,
    required this.viewingRequestId,
    required this.otherPartyName,
    required this.listingTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: true);
    // Lightweight polling so both sides see new messages without a full
    // realtime/socket layer — good enough for a per-thread chat like this.
    _poller = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = false}) async {
    if (!AuthSession.isLoggedIn) return;
    if (showSpinner) setState(() => _loading = true);
    try {
      final messages = await BackendRepository.fetchMessageThread(widget.viewingRequestId);
      if (!mounted) return;
      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (mounted && showSpinner) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      // stay on whatever we last had; will retry on next poll tick
    } finally {
      if (mounted && showSpinner) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await BackendRepository.sendMessage(widget.viewingRequestId, text);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, sent];
        _controller.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ApiException catch (e) {
      if (mounted) showActionSnackBar(context, e.message);
    } on ApiUnreachableException {
      if (mounted) showActionSnackBar(context, 'Could not send — check your connection');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthSession.userId;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.otherPartyName, style: const TextStyle(fontSize: 16)),
            Text(
              widget.listingTitle,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        message: 'Say hello and ask any questions about the flat.',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final isMine = m.senderId == myId;
                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                              decoration: BoxDecoration(
                                color: isMine ? AppColors.parade : AppColors.paperDim,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  topRight: const Radius.circular(14),
                                  bottomLeft: Radius.circular(isMine ? 14 : 2),
                                  bottomRight: Radius.circular(isMine ? 2 : 14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    m.content,
                                    style: TextStyle(color: isMine ? Colors.white : AppColors.ink),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeLabel(m.sentAt),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isMine ? Colors.white.withValues(alpha: 0.75) : AppColors.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.otherPartyName}…',
                        filled: true,
                        fillColor: AppColors.paperDim,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
