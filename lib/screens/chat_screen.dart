import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
// Removed swap status updates from Chat; actions live in My Swaps screen
import '../models/message_model.dart';
import '../services/swap_service.dart';
import 'confirm_swap_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String? swapId;
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    this.swapId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatService().markUnreadAsSeen(widget.chatId, widget.currentUserId);
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ChatService().sendMessage(
        widget.chatId,
        widget.currentUserId,
        text,
      );
      _controller.clear();
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  Widget _buildSwapStatusBanner(
    Map<String, dynamic> swap,
    bool isRecipient,
    bool isPending,
    bool isAccepted,
    bool isRejected,
  ) {
    // Status reflected only via visual banner; actions handled in My Swaps
    // We intentionally don't branch on raw status here; booleans already derived
    Color color;
    String text;
    if (isRejected) {
      color = Colors.red;
      text = 'Swap Rejected.';
    } else if (swap['status'] == 'confirmed') {
      color = Colors.green;
      text = 'Swap Confirmed ✅ – discuss delivery';
    } else if (isAccepted) {
      color = Colors.blue;
      text = 'Negotiation in progress – waiting for confirmation';
    } else {
      color = Colors.amber;
      text = 'Swap Pending – Waiting for receiver.';
    }
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if (isAccepted && isRecipient) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    // Navigate to confirm screen
                    final listingOfferedId = (swap['listingOfferedId'] ?? '')
                        .toString();
                    final listingRequestedId =
                        (swap['listingRequestedId'] ?? '').toString();
                    if (listingOfferedId.isEmpty || listingRequestedId.isEmpty)
                      return;
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConfirmSwapScreen(
                          swapId: widget.swapId!,
                          listingOfferedId: listingOfferedId,
                          listingRequestedId: listingRequestedId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await SwapService().updateSwapStatus(
                      widget.swapId!,
                      'rejected',
                    );
                  },
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppBarTitleWithStatus(Map<String, dynamic> swap) {
    String status = swap['status'] ?? '';
    return Row(
      children: [
        const Text('Chat'),
        if (status.isNotEmpty) ...[
          const SizedBox(width: 12),
          Chip(label: Text(status, style: const TextStyle(fontSize: 12))),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.swapId == null) {
      // No swapId, fallback to original UI
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: _buildChatBody(),
      );
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('swaps')
          .doc(widget.swapId)
          .snapshots(),
      builder: (context, snapshot) {
        final swap = snapshot.data?.data() as Map<String, dynamic>?;
        if (swap == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: _buildChatBody(),
          );
        }
        final status = swap['status'] ?? '';
        final toUserId = swap['toUserId'] ?? '';
        final isRecipient = widget.currentUserId == toUserId;
        final isPending = status == 'pending';
        final isAccepted = status == 'accepted';
        final isRejected = status == 'rejected';
        return Scaffold(
          appBar: AppBar(title: _buildAppBarTitleWithStatus(swap)),
          body: Column(
            children: [
              _buildSwapStatusBanner(
                swap,
                isRecipient,
                isPending,
                isAccepted,
                isRejected,
              ),
              Expanded(child: _buildChatBody()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: ChatService().getMessagesStream(widget.chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snapshot.data ?? [];
              return ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  final isMe = msg.senderId == widget.currentUserId;
                  final seen = msg.seen == true;
                  final ts = msg.timestamp is Timestamp
                      ? (msg.timestamp as Timestamp).toDate()
                      : null;
                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(msg.text, style: const TextStyle(fontSize: 16)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ts != null)
                                Text(
                                  '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (isMe && seen) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.done_all,
                                  size: 14,
                                  color: Colors.green,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                onPressed: _sending ? null : _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
