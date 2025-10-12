import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../services/swap_service.dart';
import 'confirm_swap_screen.dart';
import 'location_selection_modal.dart';

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mark messages as read when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  /// Mark all unread messages as read for current user
  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(
        widget.chatId,
        widget.currentUserId,
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      // Get receiver ID from swap if available
      String? receiverId;
      if (widget.swapId != null) {
        final swapDoc = await FirebaseFirestore.instance
            .collection('swaps')
            .doc(widget.swapId)
            .get();

        if (swapDoc.exists) {
          final swapData = swapDoc.data();
          final fromUserId = swapData?['fromUserId'];
          final toUserId = swapData?['toUserId'];

          // Set receiver as the other user in the swap
          receiverId = widget.currentUserId == fromUserId
              ? toUserId
              : fromUserId;
        }
      }

      await _chatService.sendMessage(
        widget.chatId,
        widget.currentUserId,
        text,
        receiverId: receiverId,
      );

      _controller.clear();

      // Scroll to bottom after sending
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
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
      color = const Color(0xFFEF4444);
      text = 'Swap Declined';
      subtitle = 'This swap request was declined';
    } else if (swap['status'] == 'ready_for_delivery') {
      icon = Icons.local_shipping;
      color = const Color(0xFF10B981);
      text = 'Swap Completed';
      subtitle = 'Both locations confirmed! Ready for delivery';
    } else if (swap['status'] == 'confirmed') {
      icon = Icons.check_circle_outline;
      color = const Color(0xFF10B981);
      text = 'Swap Confirmed';
      subtitle = 'You can now arrange the exchange';
    } else if (isAccepted) {
      icon = Icons.pending_outlined;
      color = const Color(0xFF14B8A6);
      text = 'Awaiting Confirmation';
      subtitle = 'Waiting for final approval';
    } else {
      icon = Icons.access_time_outlined;
      color = const Color(0xFF06B6D4);
      text = 'Pending Response';
      subtitle = 'Waiting for receiver to accept';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1),
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
                      backgroundColor: const Color(0xFF10B981),
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
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(
                        color: Color(0xFFD1FAE5),
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

  Widget _buildLocationConfirmationBanner(Map<String, dynamic> swap) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    final status = swap['status'] ?? '';
    final user01LocationConfirmed =
        swap['user01LocationConfirmed'] as bool? ?? false;
    final user02LocationConfirmed =
        swap['user02LocationConfirmed'] as bool? ?? false;
    final bothConfirmed = swap['bothConfirmed'] as bool? ?? false;

    if (status != 'confirmed' || bothConfirmed) {
      return const SizedBox.shrink();
    }

    final fromUserId = swap['fromUserId'] as String?;
    final toUserId = swap['toUserId'] as String?;

    bool needsLocation = false;
    if (currentUserId == fromUserId && !user01LocationConfirmed) {
      needsLocation = true;
    } else if (currentUserId == toUserId && !user02LocationConfirmed) {
      needsLocation = true;
    }

    if (!needsLocation) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D9D78).withOpacity(0.1),
            const Color(0xFF10B981).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D9D78).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2D9D78).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF2D9D78),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '📍 Please provide your delivery location',
                  style: TextStyle(
                    color: Color(0xFF2D9D78),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add your location to complete the swap setup.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showLocationSelectionModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D9D78),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Give Location',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationSelectionModal() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || widget.swapId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          LocationSelectionModal(swapId: widget.swapId!, userId: currentUserId),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location added successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Widget _buildAppBarTitleWithStatus(Map<String, dynamic> swap) {
    String status = swap['status'] ?? '';
    String displayStatus = status;
    Color statusColor = const Color(0xFF14B8A6);

    switch (status) {
      case 'ready_for_delivery':
        displayStatus = 'COMPLETED';
        statusColor = const Color(0xFF10B981);
        break;
      case 'confirmed':
        displayStatus = 'CONFIRMED';
        statusColor = const Color(0xFF10B981);
        break;
      case 'accepted':
        displayStatus = 'ACCEPTED';
        statusColor = const Color(0xFF14B8A6);
        break;
      case 'pending':
        displayStatus = 'PENDING';
        statusColor = const Color(0xFF06B6D4);
        break;
      case 'rejected':
        displayStatus = 'DECLINED';
        statusColor = const Color(0xFFEF4444);
        break;
    }

    return Row(
      children: [
        const Text('Chat', style: TextStyle(color: Color(0xFF0F172A))),
        if (displayStatus.isNotEmpty) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              displayStatus,
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
        backgroundColor: const Color(0xFFF0FDF4),
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
            backgroundColor: const Color(0xFFF0FDF4),
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
          backgroundColor: const Color(0xFFF0FDF4),
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
              _buildLocationConfirmationBanner(swap),
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
            stream: _chatService.getMessagesStream(widget.chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF10B981)),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading messages: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
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
                  final isRead = msg.isRead;
                  final ts = msg.timestamp?.toDate();

                  // Show date separator
                  bool showDate = false;
                  if (idx == 0) {
                    showDate = true;
                  } else {
                    final prevMsg = messages[idx - 1];
                    final prevTs = prevMsg.timestamp?.toDate();
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
                                ? const Color(0xFF10B981)
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
                                  // Read receipts for sent messages (WhatsApp style)
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isRead
                                          ? Icons
                                                .done_all_rounded // Double check when read
                                          : Icons
                                                .check_rounded, // Single check when delivered
                                      size: 16,
                                      color: isRead
                                          ? const Color(
                                              0xFF0EA5E9,
                                            ) // Blue when read
                                          : Colors.white.withOpacity(
                                              0.7,
                                            ), // Grey when delivered
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
                      color: const Color(0xFFECFDF5),
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
                    color: Color(0xFF10B981),
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
