import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class ChatRoom extends StatefulWidget {
  final String peerId;
  final String peerName;

  const ChatRoom({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final user = FirebaseAuth.instance.currentUser;

  String get _chatId => ChatService.chatIdFor(user!.uid, widget.peerId);

  @override
  void initState() {
    super.initState();
    print('=== ChatRoom.initState ===');
    print('Current User UID: ${user?.uid}');
    print('Current User Email: ${user?.email}');
    print('Peer ID: ${widget.peerId}');
    print('Peer Name: ${widget.peerName}');
    print('Generated Chat ID: $_chatId');
    print('Participants: [${user?.uid}, ${widget.peerId}]');
    print('========================');
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (user == null) {
      print('ERROR: User is null, cannot send message');
      return;
    }

    print('=== ChatRoom._send ===');
    print('Sender UID: ${user!.uid}');
    print('Sender Email: ${user!.email}');
    print('Chat ID: $_chatId');
    print('Message Text: $text');
    print('Participants: [${user!.uid}, ${widget.peerId}]');
    print('=======================');

    try {
      await ChatService.sendMessage(
        chatId: _chatId,
        participants: [user!.uid, widget.peerId],
        senderId: user!.uid,
        senderEmail: user!.email ?? '',
        text: text,
      );

      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('ERROR in ChatRoom._send: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ChatService.messagesStream(_chatId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  final items = docs.map((doc) {
                    final data = doc.data();
                    final uid = (data['senderId'] ?? '') as String;
                    final text = data['text']?.toString() ?? '';
                    final email = data['email']?.toString() ?? '';
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    String time = '';
                    if (ts != null) {
                      final dt = ts.toDate();
                      time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    }

                    final bool isMe = user != null && uid == user!.uid;
                    final avatarLabel = (email.isNotEmpty ? email[0].toUpperCase() : (uid.isNotEmpty ? uid[0].toUpperCase() : '?'));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blueGrey.shade200,
                              child: Text(avatarLabel, style: const TextStyle(fontSize: 14, color: Colors.white)),
                            ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: isMe ? Colors.blueAccent.shade100 : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: Radius.circular(isMe ? 12 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 12),
                                    ),
                                  ),
                                  child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15)),
                                ),
                                if (time.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(time, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isMe)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.indigo.shade400,
                              child: Text(avatarLabel, style: const TextStyle(fontSize: 14, color: Colors.white)),
                            ),
                        ],
                      ),
                    );
                  }).toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      try {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      } catch (_) {}
                    }
                  });

                  return ListView(controller: _scrollController, padding: const EdgeInsets.symmetric(vertical: 8), children: items);
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Message ${widget.peerName}",
                        fillColor: Colors.grey[100],
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                    child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _send),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
