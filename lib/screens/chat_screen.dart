import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';

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
    IconData icon;
    Color color;
    String text;
    String subtitle;

    if (isRejected) {
      icon = Icons.cancel_outlined;
      color = const Color(0xFFEF4444); // Softer red
      text = 'Swap Declined';
      subtitle = 'This swap request was declined';
    } else if (swap['status'] == 'confirmed') {
      icon = Icons.check_circle_outline;
      color = const Color(0xFF10B981); // Emerald green
      text = 'Swap Confirmed';
      subtitle = 'You can now arrange the exchange';
    } else if (isAccepted) {
      icon = Icons.pending_outlined;
      color = const Color(0xFF14B8A6); // Teal
      text = 'Awaiting Confirmation';
      subtitle = 'Waiting for final approval';
    } else {
      icon = Icons.access_time_outlined;
      color = const Color(0xFF06B6D4); // Cyan
      text = 'Pending Response';
      subtitle = 'Waiting for receiver to accept';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD1FAE5),
          width: 1,
        ), // Mint border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isAccepted && isRecipient) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final listingOfferedId = (swap['listingOfferedId'] ?? '')
                          .toString();
                      final listingRequestedId =
                          (swap['listingRequestedId'] ?? '').toString();
                      if (listingOfferedId.isEmpty ||
                          listingRequestedId.isEmpty)
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
                      backgroundColor: const Color(0xFF10B981), // Emerald green
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await SwapService().updateSwapStatus(
                        widget.swapId!,
                        'rejected',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444), // Softer red
                      side: const BorderSide(
                        color: Color(0xFFD1FAE5), // Mint border
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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
        const Text('Chat', style: TextStyle(color: Color(0xFF0F172A))),
        if (status.isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF14B8A6), // Teal
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.swapId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0FDF4), // Mint background
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: const Text('Chat'),
          iconTheme: const IconThemeData(color: Color(0xFF10B981)),
        ),
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
            backgroundColor: const Color(0xFFF0FDF4), // Mint background
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: false,
              title: const Text('Chat'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: const Color(0xFF10B981),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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
          backgroundColor: const Color(0xFFF0FDF4), // Mint background
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            title: _buildAppBarTitleWithStatus(swap),
            iconTheme: const IconThemeData(color: Color(0xFF10B981)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF10B981),
              onPressed: () => Navigator.pop(context),
            ),
          ),
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
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF10B981),
                  ), // Emerald
                );
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  final isMe = msg.senderId == widget.currentUserId;
                  final seen = msg.seen == true;
                  final ts = msg.timestamp is Timestamp
                      ? (msg.timestamp as Timestamp).toDate()
                      : null;

                  // Show date separator
                  bool showDate = false;
                  if (idx == 0) {
                    showDate = true;
                  } else {
                    final prevMsg = messages[idx - 1];
                    final prevTs = prevMsg.timestamp is Timestamp
                        ? (prevMsg.timestamp as Timestamp).toDate()
                        : null;
                    if (ts != null && prevTs != null) {
                      showDate =
                          ts.day != prevTs.day ||
                          ts.month != prevTs.month ||
                          ts.year != prevTs.year;
                    }
                  }

                  return Column(
                    children: [
                      if (showDate && ts != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _formatDate(ts),
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(
                                    0xFF10B981,
                                  ) // Emerald for sent messages
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (ts != null)
                                    Text(
                                      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe
                                            ? Colors.white.withOpacity(0.7)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      seen
                                          ? Icons.done_all_rounded
                                          : Icons.done_rounded,
                                      size: 14,
                                      color: seen
                                          ? const Color(
                                              0xFF34D399,
                                            ) // Light emerald for seen
                                          : Colors.white.withOpacity(0.7),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          color: Colors.white,
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5), // Light mint
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald green
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    color: Colors.white,
                    onPressed: _sending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
